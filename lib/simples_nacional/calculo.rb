# frozen_string_literal: true

module SimplesNacional
  # O cálculo do DAS (LC 123/2006, art. 18):
  #   1. a faixa vem da receita bruta dos 12 meses anteriores (RBT12);
  #   2. alíquota efetiva = (RBT12 × alíquota nominal − parcela a deduzir) ÷ RBT12 (§ 1º-A);
  #   3. a alíquota efetiva é dividida entre os tributos (ver Reparticao);
  #   4. DAS = receita do mês × soma dos percentuais dos tributos (§ 3º). Nas faixas 1 a 5 a
  #      soma é a própria alíquota efetiva; na 6ª, entra também o ICMS ou o ISS.
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

    # fator_r: o Fator R usado para escolher o anexo, ou nil quando o anexo foi informado.
    # aliquota_efetiva: o percentual que o DAS aplica sobre a receita do mês.
    # tributos: a divisão do DAS, na ordem do anexo.
    Resultado = Data.define(:anexo, :fator_r, :faixa, :aliquota_efetiva, :das, :tributos, :passos)

    # percentual: parte da receita do mês (Rational); valor: em centavos, arredondado.
    Tributo = Data.define(:nome, :percentual, :valor)

    # anexo: 1 a 5, ou :fator_r para as atividades que ficam no Anexo III ou no V conforme
    # o Fator R. folha12 (folha de salários dos 12 meses anteriores) só é usada no Fator R.
    def self.calcular(rbt12:, receita_mes:, anexo:, folha12: nil)
      conferir_valor(rbt12, "A receita bruta dos 12 meses anteriores (RBT12)")
      conferir_valor(receita_mes, "A receita do mês")
      return com_fator_r(rbt12, receita_mes, folha12) if anexo == :fator_r

      tabela = tabelas[anexo] || raise(EntradaInvalida, "O anexo precisa ser 1, 2, 3, 4, 5 ou :fator_r.")
      resultado(tabela, rbt12, receita_mes, nil, [Passos.anexo(tabela)])
    end

    def self.com_fator_r(rbt12, receita_mes, folha12)
      raise EntradaInvalida, "Para usar o Fator R, informe a folha de salários dos 12 meses anteriores." if folha12.nil?

      # Folha zero é possível (empresa sem empregados nem pró-labore): o Fator R fica em 0%.
      conferir_valor(folha12, "A folha de salários dos 12 meses anteriores", minimo: 0)
      numero, fator = FatorR.anexo(rbt12, folha12)
      tabela = tabelas.fetch(numero)
      resultado(tabela, rbt12, receita_mes, fator, [Passos.fator_r(tabela, rbt12, folha12, fator)])
    end

    # A conta em si, com as entradas já conferidas. "passos" chega com a explicação de
    # como o anexo foi escolhido; a faixa, a alíquota e o DAS entram aqui.
    def self.resultado(tabela, rbt12, receita_mes, fator_r, passos)
      faixa = tabela.faixas.find { |item| rbt12 <= centavos(item.ate) }
      efetiva = aliquota_efetiva(faixa, rbt12)
      percentuais = Reparticao.percentuais(tabela, faixa, rbt12, efetiva)
      total, das, tributos = valores(receita_mes, percentuais)

      passos += [Passos.faixa(tabela, faixa, rbt12), Passos.aliquota_efetiva(faixa, rbt12, efetiva),
                 PassoDaDivisao.montar(tabela, faixa, rbt12, efetiva, percentuais),
                 Passos.das(receita_mes, efetiva, total, das, tributos)]
      Resultado.new(anexo: tabela, fator_r:, faixa:, aliquota_efetiva: total, das:, tributos:, passos:)
    end

    # Percentual total do DAS, o DAS em centavos e o valor de cada tributo. Cada tributo é
    # arredondado sozinho, por isso a soma deles pode diferir do DAS em alguns centavos.
    def self.valores(receita_mes, percentuais)
      total = percentuais.values.sum
      tributos = percentuais.map do |nome, percentual|
        Tributo.new(nome:, percentual:, valor: (receita_mes * percentual).round(half: :up))
      end
      [total, (receita_mes * total).round(half: :up), tributos]
    end

    # (RBT12 × alíquota nominal − parcela a deduzir) ÷ RBT12, com a RBT12 em centavos.
    def self.aliquota_efetiva(faixa, rbt12) = ((rbt12 * faixa.aliquota) - centavos(faixa.deduzir)) / rbt12

    # As tabelas são lidas uma vez só e ficam guardadas.
    def self.tabelas
      @tabelas ||= Tabelas.todas
    end

    # Reais (Rational, como vêm das tabelas) → centavos (Integer).
    def self.centavos(reais) = (reais * 100).round

    # minimo: 1 centavo para as receitas; 0 para a folha.
    def self.conferir_valor(valor, nome, minimo: 1)
      raise EntradaInvalida, "#{nome} precisa ser um número inteiro de centavos." unless valor.is_a?(Integer)
      if valor < minimo
        raise EntradaInvalida, minimo.zero? ? "#{nome} não pode ser negativa." : "#{nome} precisa ser maior que zero."
      end
      return if valor <= TETO

      raise EntradaInvalida, "#{nome} passa de #{Formato.reais(TETO)}, o limite do Simples Nacional para a " \
                             "empresa de pequeno porte (LC 123/2006, art. 3º, II)."
    end

    private_class_method :conferir_valor, :com_fator_r, :resultado, :valores
  end
end
