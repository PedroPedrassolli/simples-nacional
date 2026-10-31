# frozen_string_literal: true

module SimplesNacional
  # O passo "Divisão entre os tributos": como a alíquota efetiva vira o percentual de cada
  # tributo (ver Reparticao), com as exceções da 6ª faixa, do teto do ISS e da CPP no Anexo IV.
  module PassoDaDivisao
    def self.montar(tabela, faixa, rbt12, efetiva, percentuais)
      iss = Reparticao.percentual_local(tabela, faixa, rbt12, efetiva)
      teto = percentuais.key?("ISS") && iss > Reparticao::TETO_ISS
      textos = [texto_reparticao(tabela, faixa, efetiva, exemplo: !teto),
                texto_sexta_faixa(tabela, faixa, rbt12, percentuais)]
      textos << texto_teto_do_iss(iss, percentuais) if teto
      textos << texto_cpp(tabela)
      Passos::Passo.new(titulo: "Divisão entre os tributos", texto: textos.compact.join(" "), fonte: fonte(tabela))
    end

    def self.fonte(tabela)
      fonte = "Res. CGSN 140/2018, art. 21, III; LC 123/2006, Anexo #{Passos.romano(tabela.numero)}"
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

    # Na 6ª faixa, o ICMS ou o ISS vem da alíquota efetiva da 5ª faixa, com a mesma RBT12
    # (quando ele está no DAS: acima do sublimite, ver o passo do sublimite).
    def self.texto_sexta_faixa(tabela, faixa, rbt12, percentuais)
      local = Reparticao.imposto_local(tabela)
      return unless faixa.numero == 6 && percentuais.key?(local)

      quinta = tabela.faixas[4]
      "O #{local} usa a alíquota efetiva da 5ª faixa com a mesma RBT12, #{conta_da_quinta(quinta, rbt12)}, " \
        "vezes os #{Formato.percentual(quinta.reparticao.fetch(local))} do #{local} na 5ª faixa."
    end

    # "(R$ 4.000.000,00 × 14,30% − R$ 87.300,00) ÷ R$ 4.000.000,00 = 12,1175%"
    def self.conta_da_quinta(quinta, rbt12)
      "(#{Formato.reais(rbt12)} × #{Formato.percentual(quinta.aliquota)} − " \
        "#{Formato.reais(Calculo.centavos(quinta.deduzir))}) ÷ #{Formato.reais(rbt12)} = " \
        "#{Formato.percentual(Calculo.aliquota_efetiva(quinta, rbt12), 4)}"
    end

    # O ISS fica em 5% e os federais dividem o resto do total, cada um com o seu peso.
    def self.texto_teto_do_iss(iss, percentuais)
      resto = percentuais.values.sum - Reparticao::TETO_ISS
      nome, percentual = percentuais.first
      conta = "(#{Formato.percentual(resto + Reparticao::TETO_ISS, 4)} − 5%)"
      "O ISS daria #{Formato.percentual(iss, 4)}, mais que o máximo de 5%: fica em 5% e os tributos " \
        "federais dividem o resto, na proporção de cada um. Por exemplo, #{nome} = #{conta} × " \
        "#{Formato.percentual(percentual / resto)} = #{Formato.percentual(percentual, 4)}."
    end

    def self.texto_cpp(tabela)
      return unless tabela.numero == 4

      "No Anexo IV, a contribuição patronal ao INSS (CPP) não entra no DAS: é paga à parte, como " \
        "nas outras empresas."
    end

    private_class_method :fonte, :texto_reparticao, :inicio_da_reparticao, :texto_sexta_faixa, :conta_da_quinta,
                         :texto_teto_do_iss, :texto_cpp
  end
end
