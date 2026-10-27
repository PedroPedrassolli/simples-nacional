# frozen_string_literal: true

module SimplesNacional
  # Monta a explicação da conta, um passo por etapa, com a base legal de cada uma.
  # A página só mostra estes textos: a regra fica toda aqui no Ruby.
  module Passos
    Passo = Data.define(:titulo, :texto, :fonte)

    ROMANOS = { 1 => "I", 2 => "II", 3 => "III", 4 => "IV", 5 => "V" }.freeze

    def self.romano(numero) = ROMANOS.fetch(numero)

    def self.anexo(tabela)
      Passo.new(titulo: "Anexo",
                texto: "Você informou o Anexo #{romano(tabela.numero)}: #{tabela.nome}.",
                fonte: "LC 123/2006, Anexo #{romano(tabela.numero)}")
    end

    def self.faixa(tabela, faixa, rbt12)
      Passo.new(titulo: "Faixa",
                texto: "A receita bruta dos 12 meses anteriores (RBT12) é de #{Formato.reais(rbt12)} e fica na " \
                       "#{faixa.numero}ª faixa do Anexo #{romano(tabela.numero)}, #{limites(tabela, faixa)}: " \
                       "alíquota nominal de #{Formato.percentual(faixa.aliquota)} e parcela a deduzir de " \
                       "#{Formato.reais(Calculo.centavos(faixa.deduzir))}.",
                fonte: "LC 123/2006, art. 18, § 1º, e Anexo #{romano(tabela.numero)}")
    end

    # "até R$ 180.000,00" na 1ª faixa; "de R$ 180.000,01 a R$ 360.000,00" nas outras.
    def self.limites(tabela, faixa)
      ate = Formato.reais(Calculo.centavos(faixa.ate))
      return "até #{ate}" if faixa.numero == 1

      anterior = tabela.faixas[faixa.numero - 2]
      "de #{Formato.reais(Calculo.centavos(anterior.ate) + 1)} a #{ate}"
    end

    def self.aliquota_efetiva(faixa, rbt12, efetiva)
      conta = "(#{Formato.reais(rbt12)} × #{Formato.percentual(faixa.aliquota)} − " \
              "#{Formato.reais(Calculo.centavos(faixa.deduzir))}) ÷ #{Formato.reais(rbt12)}"
      Passo.new(titulo: "Alíquota efetiva",
                texto: "(RBT12 × alíquota nominal − parcela a deduzir) ÷ RBT12 = #{conta} = " \
                       "#{Formato.percentual(efetiva, 4)}.",
                fonte: "LC 123/2006, art. 18, § 1º-A")
    end

    def self.das(receita_mes, efetiva, das)
      Passo.new(titulo: "DAS estimado",
                texto: "Receita do mês × alíquota efetiva = #{Formato.reais(receita_mes)} × " \
                       "#{Formato.percentual(efetiva, 4)} = #{Formato.reais(das)}. A conta usa a alíquota " \
                       "efetiva exata, sem cortar casas decimais, e arredonda o resultado para o centavo.",
                fonte: "LC 123/2006, art. 18, § 3º")
    end
  end
end
