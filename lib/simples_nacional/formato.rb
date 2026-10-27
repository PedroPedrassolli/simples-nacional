# frozen_string_literal: true

module SimplesNacional
  # Números no jeito brasileiro, para os passos da conta: "R$ 1.234,56" e "9,9720%".
  module Formato
    # Centavos (Integer) → "R$ 1.234,56".
    def self.reais(centavos)
      inteiro, resto = centavos.divmod(100)
      # Separa os milhares com ponto: 1234567 → "1.234.567".
      milhares = inteiro.to_s.reverse.scan(/\d{1,3}/).join(".").reverse
      "R$ #{milhares},#{resto.to_s.rjust(2, '0')}"
    end

    # Fração (Rational) → percentual com vírgula, como "9,9720%".
    #
    # Corta as casas a mais em vez de arredondar: assim um Fator R de 27,999% aparece
    # como "27,99%", e não como "28,00%", que daria a impressão de outro anexo.
    def self.percentual(fracao, casas = 2)
      escala = 10**casas
      inteiro, decimais = (fracao * 100 * escala).floor.divmod(escala)
      "#{inteiro},#{decimais.to_s.rjust(casas, '0')}%"
    end
  end
end
