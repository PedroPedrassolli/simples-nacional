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
  #   SimplesNacional.calcular(periodo: "2026-03", rbt12: 50_000_000, receita_mes: 4_000_000, anexo: 3).das
  #   # => 398880 (R$ 3.988,80)
  module Calculo
    # Os nomes antigos continuam valendo: a conferência das entradas mudou para Entrada.
    TETO = Entrada::TETO
    EntradaInvalida = Entrada::EntradaInvalida

    # periodo: o mês de apuração (Date). rbt12: a RBT12 que a conta usou (anualizada no
    # início de atividade). fator_r: o Fator R, ou nil quando o anexo foi informado.
    # aliquota_efetiva: o percentual que o DAS aplica sobre a receita do mês.
    # tributos: a divisão do DAS, na ordem do anexo.
    # situacao: o ICMS/ISS e o sublimite (Sublimite::Situacao).
    Resultado = Data.define(:periodo, :anexo, :fator_r, :faixa, :rbt12, :situacao, :aliquota_efetiva, :das,
                            :tributos, :passos)

    # percentual: parte da receita do mês (Rational); valor: em centavos, arredondado.
    Tributo = Data.define(:nome, :percentual, :valor)

    # Recebe os argumentos de Entrada.conferir: periodo ("2026-03"), anexo (1 a 5, ou
    # :fator_r para as atividades que ficam no Anexo III ou no V conforme o Fator R),
    # receita_mes, rbt12, folha12 (só no Fator R), inicio ("2025-11", se a empresa tem
    # menos de 12 meses de atividade), receita_ano e receita_ano_anterior (sublimite).
    def self.calcular(**)
      dados = Entrada.conferir(**)
      passos = Passos.inicio(dados)
      return com_fator_r(dados, passos) if dados.anexo == :fator_r

      tabela = tabelas[dados.anexo] || raise(EntradaInvalida, "O anexo precisa ser 1, 2, 3, 4, 5 ou :fator_r.")
      resultado(tabela, dados, nil, passos + [Passos.anexo(tabela)])
    end

    def self.com_fator_r(dados, passos)
      if dados.rbt12.zero?
        raise EntradaInvalida, "Sem receita antes deste mês, não dá para calcular o Fator R (folha ÷ receita): " \
                               "escolha o Anexo III ou o V."
      end

      numero, fator = FatorR.anexo(dados.rbt12, dados.folha12)
      tabela = tabelas.fetch(numero)
      resultado(tabela, dados, fator, passos + [Passos.fator_r(tabela, dados.rbt12, dados.folha12, fator)])
    end

    # A conta em si, com as entradas já conferidas. "passos" chega com a explicação de
    # como o anexo foi escolhido; a faixa, a alíquota e o DAS entram aqui.
    def self.resultado(tabela, dados, fator_r, passos)
      rbt12, faixa, efetiva = faixa_e_aliquota(tabela, dados.rbt12)
      percentuais = Reparticao.percentuais(tabela, faixa, rbt12, efetiva, dados.situacao)
      passos += [Passos.faixa(tabela, faixa, dados.rbt12), Passos.aliquota_efetiva(faixa, rbt12, efetiva),
                 PassoDaDivisao.montar(tabela, faixa, rbt12, efetiva, percentuais),
                 *PassoDoSublimite.montar(tabela, dados)]
      sem_das = Resultado.new(periodo: dados.periodo, anexo: tabela, fator_r:, faixa:, rbt12: dados.rbt12,
                              situacao: dados.situacao, aliquota_efetiva: nil, das: nil, tributos: nil, passos:)
      com_das(sem_das, dados.receita_mes, efetiva, percentuais)
    end

    # Completa o resultado com o DAS, o valor de cada tributo e o passo do DAS.
    def self.com_das(resultado, receita_mes, efetiva, percentuais)
      total, das, tributos = valores(receita_mes, percentuais)
      resultado.with(aliquota_efetiva: total, das:, tributos:,
                     passos: resultado.passos + [Passos.das(receita_mes, efetiva, total, das, tributos)])
    end

    # [RBT12 da alíquota, faixa, alíquota efetiva]. RBT12 zero vira R$ 1,00, só para achar a
    # alíquota (Res. CGSN 140/2018, art. 21, parágrafo único): sem isso a conta dividiria por zero.
    def self.faixa_e_aliquota(tabela, rbt12)
      rbt12 = 100 if rbt12.zero?
      faixa = faixa_da(tabela, rbt12)
      [rbt12, faixa, aliquota_efetiva(faixa, rbt12)]
    end

    # A faixa da RBT12. Acima do limite (o que acontece com a RBT12 anualizada no início de
    # atividade), vale a última faixa (Res. CGSN 140/2018, art. 22, § 5º).
    def self.faixa_da(tabela, rbt12) = tabela.faixas.find { |item| rbt12 <= centavos(item.ate) } || tabela.faixas.last

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

    private_class_method :com_fator_r, :resultado, :com_das, :faixa_e_aliquota, :valores
  end
end
