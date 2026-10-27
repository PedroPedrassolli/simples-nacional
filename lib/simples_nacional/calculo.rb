# frozen_string_literal: true

module SimplesNacional
  # O cálculo do DAS (LC 123/2006, art. 18):
  #   1. a faixa vem da receita bruta dos 12 meses anteriores (RBT12);
  #   2. alíquota efetiva = (RBT12 × alíquota nominal − parcela a deduzir) ÷ RBT12 (§ 1º-A);
  #   3. DAS = receita do mês × alíquota efetiva (§ 3º).
  #
  # Dinheiro entra e sai em centavos (Integer) e percentual é fração exata (Rational):
  # nenhuma conta passa por Float.
  #
  #   SimplesNacional.calcular(rbt12: 50_000_000, receita_mes: 4_000_000, anexo: 3).das
  #   # => 398880 (R$ 3.988,80)
  module Calculo
    # Limite da empresa de pequeno porte: receita bruta de até R$ 4.800.000,00 no ano
    # (LC 123/2006, art. 3º, II). A calculadora não estima acima disso.
    # https://www.planalto.gov.br/ccivil_03/leis/lcp/lcp123.htm (conferido em 27/10/2026)
    TETO = 480_000_000

    # Entrada que a calculadora não aceita. A mensagem é para quem usa a página.
    class EntradaInvalida < ArgumentError; end

    Resultado = Data.define(:anexo, :faixa, :aliquota_efetiva, :das, :passos)

    def self.calcular(rbt12:, receita_mes:, anexo:)
      conferir_valor(rbt12, "A receita bruta dos 12 meses anteriores (RBT12)")
      conferir_valor(receita_mes, "A receita do mês")
      tabela = tabelas[anexo] || raise(EntradaInvalida, "O anexo precisa ser 1, 2, 3, 4 ou 5.")

      resultado(tabela, rbt12, receita_mes, [Passos.anexo(tabela)])
    end

    # A conta em si, com as entradas já conferidas. "passos" chega com a explicação de
    # como o anexo foi escolhido; a faixa, a alíquota e o DAS entram aqui.
    def self.resultado(tabela, rbt12, receita_mes, passos)
      faixa = tabela.faixas.find { |item| rbt12 <= centavos(item.ate) }
      efetiva = aliquota_efetiva(faixa, rbt12)
      das = (receita_mes * efetiva).round(half: :up)

      passos += [Passos.faixa(tabela, faixa, rbt12), Passos.aliquota_efetiva(faixa, rbt12, efetiva),
                 Passos.das(receita_mes, efetiva, das)]
      Resultado.new(anexo: tabela, faixa: faixa, aliquota_efetiva: efetiva, das: das, passos: passos)
    end

    # (RBT12 × alíquota nominal − parcela a deduzir) ÷ RBT12, com a RBT12 em centavos.
    def self.aliquota_efetiva(faixa, rbt12) = ((rbt12 * faixa.aliquota) - centavos(faixa.deduzir)) / rbt12

    # As tabelas são lidas uma vez só e ficam guardadas.
    def self.tabelas
      @tabelas ||= Tabelas.todas
    end

    # Reais (Rational, como vêm das tabelas) → centavos (Integer).
    def self.centavos(reais) = (reais * 100).round

    def self.conferir_valor(valor, nome)
      raise EntradaInvalida, "#{nome} precisa ser um número inteiro de centavos." unless valor.is_a?(Integer)
      raise EntradaInvalida, "#{nome} precisa ser maior que zero." unless valor.positive?
      return if valor <= TETO

      raise EntradaInvalida, "#{nome} passa de #{Formato.reais(TETO)}, o limite do Simples Nacional para a " \
                             "empresa de pequeno porte (LC 123/2006, art. 3º, II)."
    end

    private_class_method :conferir_valor, :resultado
  end
end
