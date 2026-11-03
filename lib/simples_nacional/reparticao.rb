# frozen_string_literal: true

module SimplesNacional
  # Divide a alíquota efetiva entre os tributos que o DAS junta num pagamento só.
  #
  #   percentual efetivo de cada tributo = alíquota efetiva × percentual de repartição da faixa
  #   (Resolução CGSN nº 140/2018, art. 21, III; tabelas "Percentual de Repartição dos
  #   Tributos" dos Anexos I a V da LC 123/2006)
  #
  # Ajustes da mesma regra:
  # - ISS de no máximo 5%; o que passar vai para os outros tributos (federais e, a partir de
  #   2027, IBS), na proporção de cada um (art. 21, III, a, e as notas dos Anexos III e IV);
  # - na 6ª faixa, a alíquota da tabela cobre só os tributos federais. O ICMS, o ISS e o IBS
  #   usam a alíquota efetiva da 5ª faixa calculada com a RBT12 (art. 21, III, b; IV em 2027);
  # - sublimite (ver Sublimite): fora do DAS, o ICMS, o ISS e o IBS saem da conta; em 2026, na
  #   parte da receita acima do sublimite, eles usam a alíquota efetiva da 5ª faixa com
  #   R$ 3.600.000,00 (art. 24, I, b, 2). O teto de 5% do ISS vale também aí;
  # - limite (ver Limite): em 2026, na parte da receita acima de R$ 4.800.000,00, os federais
  #   usam a alíquota efetiva da 6ª faixa com R$ 4.800.000,00 (art. 24, II).
  #
  # https://normas.receita.fazenda.gov.br/sijut2consulta/link.action?idAto=92278 (conferido em 02/11/2026)
  module Reparticao
    TETO_ISS = Rational(5, 100)

    # Percentual efetivo de cada tributo, na ordem do anexo: { "IRPJ" => Rational, ... }.
    # A soma é o percentual que o DAS aplica sobre a receita.
    def self.percentuais(anexo, faixa, rbt12, efetiva, situacao = Sublimite::NO_DAS)
      sub = situacao.fracao_sublimite
      lim = situacao.fracao_limite
      partes = [[1 - sub - lim, normais(anexo, faixa, rbt12, efetiva, situacao.local)]]
      partes << [sub, acima_do_sublimite(anexo, faixa, efetiva)] if sub.positive?
      partes << [lim, acima_do_limite(anexo, situacao.local)] if lim.positive?
      ordenar(misturar(partes), anexo)
    end

    # Na 6ª faixa fora do sublimite não há ICMS/ISS/IBS calculado (art. 21, III, b, só vale
    # sem excesso), então também não há teto a redistribuir.
    def self.normais(anexo, faixa, rbt12, efetiva, local)
      return federais(faixa, efetiva) if local == :fora && faixa.numero == 6

      todos = com_teto_do_iss(federais(faixa, efetiva).merge(locais(anexo, faixa, rbt12, efetiva)), faixa)
      local == :fora ? todos.except(*Tabelas::LOCAIS) : todos
    end

    def self.acima_do_sublimite(anexo, faixa, efetiva)
      com_teto_do_iss(federais(faixa, efetiva).merge(locais_majorados(anexo)), faixa)
    end

    def self.acima_do_limite(anexo, local)
      sexta = anexo.faixas.last
      federais = federais(sexta, Calculo.aliquota_efetiva(sexta, Entrada::LIMITE))
      local == :fora ? federais : com_teto_do_iss(federais.merge(locais_majorados(anexo)), sexta)
    end

    # Partes da receita, cada uma com os seus percentuais: { tributo => soma de parte × percentual }.
    def self.misturar(partes)
      partes.each_with_object(Hash.new(0)) do |(parte, percentuais), soma|
        percentuais.each { |nome, percentual| soma[nome] += parte * percentual }
      end
    end

    # Os tributos na ordem da tabela do anexo (a mistura e o teto do ISS mudam a ordem).
    def self.ordenar(percentuais, anexo)
      ordem = anexo.faixas.first.reparticao.keys
      percentuais.sort_by { |nome, _| ordem.index(nome) || ordem.size }.to_h
    end

    def self.federais(faixa, efetiva) = faixa.reparticao.except(*Tabelas::LOCAIS).transform_values { efetiva * _1 }

    # ICMS, ISS e IBS do anexo (os que existem na 1ª faixa).
    def self.locais_do(anexo) = anexo.faixas.first.reparticao.keys & Tabelas::LOCAIS

    # Percentual dos impostos locais antes do teto de 5%.
    def self.locais(anexo, faixa, rbt12, efetiva)
      if faixa.numero == 6
        faixa = anexo.faixas[4]
        efetiva = Calculo.aliquota_efetiva(faixa, rbt12)
      end
      locais_do(anexo).to_h { |nome| [nome, efetiva * faixa.reparticao.fetch(nome)] }
    end

    # Impostos locais na parte da receita acima do sublimite (art. 24, I, b, 2).
    def self.locais_majorados(anexo)
      quinta = anexo.faixas[4]
      efetiva = Calculo.aliquota_efetiva(quinta, Sublimite::VALOR)
      locais_do(anexo).to_h { |nome| [nome, efetiva * quinta.reparticao.fetch(nome)] }
    end

    # Com ISS acima de 5%, ele fica em 5% e o resto do total é dividido entre os outros
    # tributos. Na 5ª faixa dos Anexos III e IV a lei traz os pesos prontos (teto_iss); nas
    # outras faixas, o peso é a parte de cada tributo (menos ICMS e ISS) na própria faixa. O
    # que não está entre os pesos (o IBS da 6ª faixa, que vem da 5ª) fica como está. O total não muda.
    def self.com_teto_do_iss(percentuais, faixa)
      iss = percentuais["ISS"]
      return percentuais if iss.nil? || iss <= TETO_ISS

      pesos = faixa.teto_iss || pesos_da_faixa(faixa)
      fixos = percentuais.except("ISS", *pesos.keys)
      resto = percentuais.values.sum - TETO_ISS - fixos.values.sum
      pesos.transform_values { |peso| resto * peso }.merge(fixos, "ISS" => TETO_ISS)
    end

    # Parte de cada tributo que recebe a diferença do ISS no total deles na faixa (soma 1).
    def self.pesos_da_faixa(faixa)
      recebem = faixa.reparticao.except("ICMS", "ISS")
      soma = recebem.values.sum
      recebem.transform_values { |parte| parte / soma }
    end

    private_class_method :normais, :acima_do_sublimite, :acima_do_limite, :misturar, :ordenar, :federais,
                         :com_teto_do_iss, :pesos_da_faixa
  end
end
