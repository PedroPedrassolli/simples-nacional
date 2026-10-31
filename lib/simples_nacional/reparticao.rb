# frozen_string_literal: true

module SimplesNacional
  # Divide a alíquota efetiva entre os tributos que o DAS junta num pagamento só.
  #
  #   percentual efetivo de cada tributo = alíquota efetiva × percentual de repartição da faixa
  #   (Resolução CGSN nº 140/2018, art. 21, III; tabelas "Percentual de Repartição dos
  #   Tributos" dos Anexos I a V da LC 123/2006)
  #
  # Ajustes da mesma regra:
  # - ISS de no máximo 5%; o que passar vai para os tributos federais, na proporção de cada
  #   um (art. 21, III, a, e as notas dos Anexos III e IV);
  # - na 6ª faixa, a alíquota da tabela cobre só os tributos federais. O ICMS ou o ISS usa a
  #   alíquota efetiva da 5ª faixa calculada com a RBT12 (art. 21, III, b);
  # - sublimite (ver Sublimite): fora do DAS, o ICMS/ISS sai da conta; na parte da receita
  #   acima do sublimite, ele usa a alíquota efetiva da 5ª faixa com R$ 3.600.000,00 (art. 24,
  #   I, b, 2). O teto de 5% do ISS vale também aí: o art. 21, III, a, define o máximo do
  #   percentual efetivo do ISS para toda a Resolução.
  #
  # https://normas.receita.fazenda.gov.br/sijut2consulta/link.action?idAto=92278 (conferido em 27/10/2026)
  module Reparticao
    TETO_ISS = Rational(5, 100)

    # Percentual efetivo de cada tributo, na ordem do anexo: { "IRPJ" => Rational, ... }.
    # A soma é o percentual que o DAS aplica sobre a receita do mês.
    def self.percentuais(anexo, faixa, rbt12, efetiva, situacao = Sublimite::NO_DAS)
      normais = com_local(anexo, faixa, efetiva, percentual_local(anexo, faixa, rbt12, efetiva))
      case situacao.tipo
      when :no_das then normais
      # Na 6ª faixa, sem o ICMS/ISS do art. 21, III, b, não há teto a redistribuir.
      when :fora then faixa.numero == 6 ? federais(faixa, efetiva) : normais.except(imposto_local(anexo))
      else misturar(normais, com_local(anexo, faixa, efetiva, percentual_majorado(anexo)), situacao.fracao)
      end
    end

    def self.federais(faixa, efetiva) = faixa.reparticao.except(*Tabelas::LOCAIS).transform_values { efetiva * _1 }

    def self.com_local(anexo, faixa, efetiva, local)
      com_teto_do_iss(federais(faixa, efetiva).merge(imposto_local(anexo) => local), faixa)
    end

    # Percentual do ICMS ou do ISS na parte da receita acima do sublimite.
    def self.percentual_majorado(anexo)
      quinta = anexo.faixas[4]
      Calculo.aliquota_efetiva(quinta, Sublimite::VALOR) * quinta.reparticao.fetch(imposto_local(anexo))
    end

    # Parte da receita com cada percentual: (1 − fração) com os normais, fração com os majorados.
    def self.misturar(normais, majorados, fracao)
      normais.to_h { |nome, percentual| [nome, ((1 - fracao) * percentual) + (fracao * majorados.fetch(nome))] }
    end

    # ICMS nos Anexos I e II, ISS nos Anexos III, IV e V. A 1ª faixa sempre tem um dos dois.
    def self.imposto_local(anexo) = (anexo.faixas.first.reparticao.keys & Tabelas::LOCAIS).first

    # Percentual do ICMS ou do ISS antes do teto de 5%.
    def self.percentual_local(anexo, faixa, rbt12, efetiva)
      local = imposto_local(anexo)
      return efetiva * faixa.reparticao.fetch(local) unless faixa.numero == 6

      quinta = anexo.faixas[4]
      Calculo.aliquota_efetiva(quinta, rbt12) * quinta.reparticao.fetch(local)
    end

    # Com ISS acima de 5%, ele fica em 5% e o resto do total é dividido entre os federais.
    # Na 5ª faixa dos Anexos III e IV a lei traz os pesos prontos (teto_iss); nas outras
    # faixas, o peso é a parte de cada tributo federal na própria faixa. O total não muda.
    def self.com_teto_do_iss(percentuais, faixa)
      iss = percentuais["ISS"]
      return percentuais if iss.nil? || iss <= TETO_ISS

      total = percentuais.values.sum
      pesos = faixa.teto_iss || pesos_federais(faixa)
      pesos.transform_values { |peso| (total - TETO_ISS) * peso }.merge("ISS" => TETO_ISS)
    end

    # Parte de cada tributo federal no total dos federais da faixa (soma 1).
    def self.pesos_federais(faixa)
      federais = faixa.reparticao.except(*Tabelas::LOCAIS)
      soma = federais.values.sum
      federais.transform_values { |parte| parte / soma }
    end

    private_class_method :federais, :com_local, :misturar, :com_teto_do_iss, :pesos_federais
  end
end
