# frozen_string_literal: true

module SimplesNacional
  # O passo "Divisão entre os tributos": como a alíquota efetiva vira o percentual de cada
  # tributo (ver Reparticao), com as exceções da 6ª faixa, do teto do ISS e da CPP no Anexo IV.
  module PassoDaDivisao
    def self.montar(apurada, dados)
      Passos::Passo.new(titulo: "Divisão entre os tributos", texto: textos(apurada).compact.join(" "),
                        fonte: fonte(apurada.tabela, dados.regras))
    end

    def self.textos(apurada)
      rbt12 = apurada.rbt12.zero? ? 100 : apurada.rbt12
      iss = iss_acima_do_teto(apurada, rbt12)
      [texto_reparticao(apurada.tabela, apurada.faixa, apurada.efetiva, exemplo: iss.nil?),
       texto_sexta_faixa(apurada, rbt12), (if iss
                                             texto_teto_do_iss(iss, apurada.reparticao)
                                           end), texto_cpp(apurada.tabela)]
    end

    # O ISS antes do teto de 5%, quando passa dele e está no DAS; senão nil.
    def self.iss_acima_do_teto(apurada, rbt12)
      return unless apurada.reparticao.key?("ISS")

      iss = Reparticao.locais(apurada.tabela, apurada.faixa, rbt12, apurada.efetiva)["ISS"]
      iss if iss > Reparticao::TETO_ISS
    end

    def self.fonte(tabela, regras)
      fonte = "#{regras.res}, art. 21, III; LC 123/2006, Anexo #{Passos.romano(tabela.numero)}"
      tabela.numero == 4 ? "#{fonte} e art. 13, VI" : fonte
    end

    # "IRPJ 4,00%, CSLL 3,50% e ISS 32,50%", com um exemplo da conta no primeiro tributo
    # (sem exemplo quando o teto do ISS muda a conta: o exemplo vem no texto do teto).
    def self.texto_reparticao(tabela, faixa, efetiva, exemplo:)
      partes = faixa.reparticao.map { |nome, parte| "#{nome} #{Formato.percentual(parte)}" }
      texto = "#{inicio_da_reparticao(tabela, faixa)}: #{partes[0..-2].join(', ')} e #{partes.last}."
      return texto unless exemplo

      nome, parte = faixa.reparticao.first
      "#{texto} Por exemplo, #{nome} = #{Formato.percentual(efetiva, 4)} × #{Formato.percentual(parte)} = " \
        "#{Formato.percentual(efetiva * parte, 4)}."
    end

    def self.inicio_da_reparticao(tabela, faixa)
      return "Na 6ª faixa, a alíquota efetiva cobre só os tributos federais, divididos assim" if faixa.numero == 6

      "A alíquota efetiva é dividida entre os tributos pelos percentuais da #{faixa.numero}ª faixa do " \
        "Anexo #{Passos.romano(tabela.numero)}"
    end

    # Na 6ª faixa, o ICMS, o ISS e o IBS vêm da alíquota efetiva da 5ª faixa, com a mesma RBT12
    # (quando estão no DAS: acima do sublimite, ver o passo do sublimite).
    def self.texto_sexta_faixa(apurada, rbt12)
      locais = Reparticao.locais_do(apurada.tabela) & apurada.reparticao.keys
      return unless apurada.faixa.numero == 6 && locais.any?

      quinta = apurada.tabela.faixas[4]
      "#{Formato.frase(Formato.lista(locais))} #{locais.size == 1 ? 'usa' : 'usam'} a alíquota efetiva da 5ª " \
        "faixa com a mesma RBT12, #{conta_da_quinta(quinta, rbt12)}, vezes os #{partes_da_quinta(quinta, locais)} " \
        "na 5ª faixa."
    end

    # "33,50% do ICMS" ou "33,50% do ISS e 0,17% do IBS".
    def self.partes_da_quinta(quinta, locais)
      Formato.juntar(locais.map { |nome| "#{Formato.percentual(quinta.reparticao.fetch(nome))} do #{nome}" })
    end

    # "(R$ 4.000.000,00 × 14,30% − R$ 87.300,00) ÷ R$ 4.000.000,00 = 12,1175%"
    def self.conta_da_quinta(quinta, rbt12)
      "(#{Formato.reais(rbt12)} × #{Formato.percentual(quinta.aliquota)} − " \
        "#{Formato.reais(Calculo.centavos(quinta.deduzir))}) ÷ #{Formato.reais(rbt12)} = " \
        "#{Formato.percentual(Calculo.aliquota_efetiva(quinta, rbt12), 4)}"
    end

    # O ISS fica em 5% e os outros tributos dividem o resto do total, cada um com o seu peso.
    def self.texto_teto_do_iss(iss, percentuais)
      resto = percentuais.values.sum - Reparticao::TETO_ISS
      nome, percentual = percentuais.first
      conta = "(#{Formato.percentual(resto + Reparticao::TETO_ISS, 4)} − 5%)"
      quem = percentuais.key?("IBS") ? "os tributos federais e o IBS" : "os tributos federais"
      "O ISS daria #{Formato.percentual(iss, 4)}, mais que o máximo de 5%: fica em 5% e #{quem} " \
        "dividem o resto, na proporção de cada um. Por exemplo, #{nome} = #{conta} × " \
        "#{Formato.percentual(percentual / resto)} = #{Formato.percentual(percentual, 4)}."
    end

    def self.texto_cpp(tabela)
      return unless tabela.numero == 4

      "No Anexo IV, a contribuição patronal ao INSS (CPP) não entra no DAS: é paga à parte, como " \
        "nas outras empresas."
    end

    private_class_method :textos, :iss_acima_do_teto, :fonte, :texto_reparticao, :inicio_da_reparticao,
                         :texto_sexta_faixa, :partes_da_quinta, :conta_da_quinta, :texto_teto_do_iss, :texto_cpp
  end
end
