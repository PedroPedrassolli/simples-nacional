# frozen_string_literal: true

module SimplesNacional
  # Números no jeito brasileiro, para os passos da conta: "R$ 1.234,56" e "9,9720%".
  module Formato
    MESES = %w[janeiro fevereiro março abril maio junho julho agosto setembro outubro novembro dezembro].freeze

    # Centavos → "R$ 1.234,56". Fração de centavo (a RBT12 anualizada pode ter) é
    # arredondada só no texto; a conta usa o valor exato.
    def self.reais(centavos)
      inteiro, resto = centavos.round(half: :up).divmod(100)
      # Separa os milhares com ponto: 1234567 → "1.234.567".
      milhares = inteiro.to_s.reverse.scan(/\d{1,3}/).join(".").reverse
      "R$ #{milhares},#{resto.to_s.rjust(2, '0')}"
    end

    # 1º/3/2026 (Date) → "março de 2026".
    def self.mes(data) = "#{MESES[data.month - 1]} de #{data.year}"

    # Fração (Rational) → percentual com vírgula, como "9,9720%".
    #
    # Corta as casas a mais em vez de arredondar: assim um Fator R de 27,999% aparece
    # como "27,99%", e não como "28,00%", que daria a impressão de outro anexo.
    def self.percentual(fracao, casas = 2)
      escala = 10**casas
      inteiro, decimais = (fracao * 100 * escala).floor.divmod(escala)
      "#{inteiro},#{decimais.to_s.rjust(casas, '0')}%"
    end

    # Fração sem o "%": Rational(1, 2) → "0,5000" (o FAP tem quatro casas).
    def self.decimal(fracao, casas = 4) = percentual(fracao / 100, casas).delete_suffix("%")

    # Tributos de nome feminino ("a CBS", "da Cofins").
    FEMININOS = %w[CBS Cofins CPP CSLL].freeze

    # Nomes com artigo, para os textos: ["ICMS"] → "o ICMS"; ["ICMS", "CBS"] → "o ICMS e a CBS";
    # com artigo "do": "do ICMS, do ISS e do IBS".
    def self.lista(nomes, artigo = "o")
      juntar(nomes.map do |nome|
        feminino = { "o" => "a", "do" => "da" }.fetch(artigo)
        "#{FEMININOS.include?(nome) ? feminino : artigo} #{nome}"
      end)
    end

    # Primeira letra maiúscula, para começar frase: "o ICMS" → "O ICMS".
    def self.frase(texto) = texto.sub(/\A./, &:upcase)

    # ["a"] → "a"; ["a", "b", "c"] → "a, b e c".
    def self.juntar(partes)
      return partes.first if partes.size == 1

      "#{partes[0..-2].join(', ')} e #{partes.last}"
    end
  end
end
