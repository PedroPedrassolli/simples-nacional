# frozen_string_literal: true

module SimplesNacional
  # Os passos "Faixa" e "Alíquota efetiva" de uma receita do mês.
  module PassoDaFaixa
    Passo = Passos::Passo

    def self.faixa(apurada, dados)
      tabela = apurada.tabela
      faixa = apurada.faixa
      romano = Passos.romano(tabela.numero)
      Passo.new(titulo: "Faixa",
                texto: "#{inicio(apurada,
                                 dados)} #{faixa.numero}ª faixa do Anexo #{romano}, #{limites(tabela, faixa)}: " \
                       "alíquota nominal de #{Formato.percentual(faixa.aliquota)} e parcela a deduzir de " \
                       "#{Formato.reais(Calculo.centavos(faixa.deduzir))}.",
                fonte: "LC 123/2006, art. 18, § 1º, e Anexo #{romano}#{exportacao(apurada, dados)}")
    end

    def self.inicio(apurada, dados)
      return "No 1º e no 2º mês de atividade, a conta usa a" if dados.primeira_faixa

      texto_da_rbt12(apurada.rbt12, apurada.atividade.exportacao?, dados.regras)
    end

    def self.exportacao(apurada, dados) = apurada.atividade.exportacao? ? "; #{dados.regras.res}, art. 23" : ""

    # O começo do passo da faixa, com as duas exceções da RBT12.
    def self.texto_da_rbt12(rbt12, exportacao, regras)
      nome = exportacao ? "A RBT12 da exportação (que é separada da do mercado interno)" : "A RBT12"
      if rbt12.zero?
        return "#{nome} é zero. Só para achar a alíquota, a conta usa R$ 1,00 (#{regras.res}, art. 21, " \
               "parágrafo único), que fica na"
      end
      return "#{nome} é de #{Formato.reais(rbt12)} e fica na" if rbt12 <= Entrada::LIMITE

      "#{nome} é de #{Formato.reais(rbt12)}, acima do limite de #{Formato.reais(Entrada::LIMITE)}: a conta usa a " \
        "última faixa (#{regras.res}, art. 22, § 5º), a"
    end

    # "até R$ 180.000,00" na 1ª faixa; "de R$ 180.000,01 a R$ 360.000,00" nas outras.
    def self.limites(tabela, faixa)
      ate = Formato.reais(Calculo.centavos(faixa.ate))
      return "até #{ate}" if faixa.numero == 1

      anterior = tabela.faixas[faixa.numero - 2]
      "de #{Formato.reais(Calculo.centavos(anterior.ate) + 1)} a #{ate}"
    end

    def self.aliquota_efetiva(apurada, dados)
      return primeira_faixa(apurada, dados.regras) if dados.primeira_faixa

      faixa = apurada.faixa
      rbt12 = Formato.reais(apurada.rbt12.zero? ? 100 : apurada.rbt12)
      deduzir = Formato.reais(Calculo.centavos(faixa.deduzir))
      conta = "(#{rbt12} × #{Formato.percentual(faixa.aliquota)} − #{deduzir}) ÷ #{rbt12}"
      Passo.new(titulo: "Alíquota efetiva", fonte: "LC 123/2006, art. 18, § 1º-A",
                texto: "(RBT12 × alíquota nominal − parcela a deduzir) ÷ RBT12 = #{conta} = " \
                       "#{Formato.percentual(apurada.efetiva, 4)}.")
    end

    def self.primeira_faixa(apurada, regras)
      Passo.new(titulo: "Alíquota efetiva", fonte: "#{regras.res}, art. 22, § 2º, I",
                texto: "Sem RBT12, a alíquota efetiva é a própria alíquota nominal da 1ª faixa: " \
                       "#{Formato.percentual(apurada.efetiva, 4)}.")
    end

    private_class_method :inicio, :exportacao, :texto_da_rbt12, :limites, :primeira_faixa
  end
end
