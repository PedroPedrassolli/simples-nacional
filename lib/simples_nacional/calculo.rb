# frozen_string_literal: true

module SimplesNacional
  # O cálculo do DAS (LC 123/2006, art. 18), receita por receita, como o PGDAS-D:
  #   1. a faixa vem da receita bruta dos 12 meses anteriores (RBT12);
  #   2. alíquota efetiva = (RBT12 × alíquota nominal − parcela a deduzir) ÷ RBT12 (§ 1º-A);
  #   3. a alíquota efetiva é dividida entre os tributos (ver Reparticao);
  #   4. cada receita do mês paga a soma dos percentuais dos tributos que ela deve no DAS
  #      (ver ApuracaoDaAtividade); o DAS é a soma das receitas (§ 3º), mais o ICMS ou o ISS em
  #      valor fixo, quando há (ver ValoresFixos).
  # O que fica fora do DAS é estimado à parte (ver ForaDoDas), e a multa e os juros do DAS
  # pago em atraso também (ver Atraso).
  #
  # Dinheiro entra e sai em centavos (Integer) e percentual é fração exata (Rational):
  # nenhuma conta passa por Float.
  #
  #   SimplesNacional.calcular(periodo: "2026-03", rbt12: 50_000_000, receita_mes: 4_000_000, anexo: 3).das
  #   # => 398880 (R$ 3.988,80)
  #
  #   SimplesNacional.calcular(periodo: "2026-03", rbt12: 50_000_000,
  #                            atividades: [{ tipo: "revenda", receita: 3_000_000, opcoes: ["st_icms"] },
  #                                         { tipo: "servicos_3", receita: 1_000_000 }])
  module Calculo
    # Os nomes antigos continuam valendo: a conferência das entradas fica em Entrada.
    TETO = Entrada::TETO
    EntradaInvalida = Entrada::EntradaInvalida

    # dados: as entradas conferidas (Entrada::Dados). fator: o Fator R (FatorR::Resultado) ou nil.
    # atividades: a conta de cada receita (ApuracaoDaAtividade::Apurada). tributos: a soma dos
    # tributos de todas as receitas. fora_do_das: as estimativas (ForaDoDas::Estimativa).
    # atraso: a multa e os juros (Atraso::Resultado), ou nil sem data de pagamento.
    Resultado = Data.define(:dados, :fator, :atividades, :das, :tributos, :fora_do_das, :atraso, :passos) do
      def periodo = dados.periodo
      def situacao = dados.situacao
      # A primeira receita, para quem usa uma atividade só (o jeito antigo).
      def anexo = atividades.first.tabela
      def faixa = atividades.first.faixa
      def rbt12 = atividades.first.rbt12
      def fator_r = fator&.fator
      def receita = atividades.sum { |apurada| apurada.atividade.receita }

      # Percentual médio do DAS sobre a receita do mês (com uma receita só, a soma dos percentuais
      # dela), com o valor fixo de ICMS ou ISS, quando há.
      def aliquota_efetiva
        exatos = atividades.sum { |apurada| apurada.atividade.receita * apurada.total }
        Rational(exatos + dados.valores_fixos.values.sum, receita)
      end

      # DAS mais o que a calculadora conseguiu estimar fora dele.
      def total_estimado = das + fora_do_das.sum { |estimativa| estimativa.valor.to_i }
    end

    # percentual: parte da receita (Rational); valor: em centavos, arredondado.
    Tributo = Data.define(:nome, :percentual, :valor)

    # Aceita o jeito antigo (anexo e receita_mes) ou a lista de atividades; ver Entrada.conferir.
    def self.calcular(**)
      dados = Entrada.conferir(**)
      fator = FatorR.calcular(dados)
      apuradas = apurar(dados, fator)
      das = das(apuradas, dados)
      resultado = Resultado.new(dados:, fator:, atividades: apuradas, das:, tributos: somar(apuradas, dados),
                                fora_do_das: ForaDoDas.estimar(dados, apuradas),
                                atraso: Atraso.calcular(das, dados.periodo, dados.pagamento), passos: [])
      resultado.with(passos: Passos.montar(resultado))
    end

    def self.apurar(dados, fator)
      dados.atividades.each_with_index.map do |atividade, indice|
        ApuracaoDaAtividade.calcular(dados, atividade, indice + 1, fator)
      end
    end

    # A soma das receitas mais o ICMS ou o ISS em valor fixo, que não depende da receita.
    def self.das(apuradas, dados) = apuradas.sum(&:valor) + dados.valores_fixos.values.sum

    # Cada tributo de cada receita, arredondado sozinho. Por isso a soma deles pode diferir
    # do valor da receita em alguns centavos.
    def self.tributos(receita, percentuais)
      percentuais.map do |nome, percentual|
        Tributo.new(nome:, percentual:, valor: (receita * percentual).round(half: :up))
      end
    end

    # Os tributos de todas as receitas juntos: valor somado e percentual sobre a receita total.
    # O valor fixo de ICMS ou ISS entra no fim, com o nome "ISS (valor fixo)".
    def self.somar(apuradas, dados)
      receita = apuradas.sum { |apurada| apurada.atividade.receita }
      nomes = apuradas.flat_map { |apurada| apurada.percentuais.keys }.uniq
      fixos = dados.valores_fixos.map do |nome, valor|
        Tributo.new(nome: "#{nome} (valor fixo)", percentual: Rational(valor, receita), valor:)
      end
      nomes.map { |nome| somar_um(nome, apuradas, receita) } + fixos
    end

    def self.somar_um(nome, apuradas, receita)
      valor = apuradas.sum { |apurada| apurada.tributos.find { |tributo| tributo.nome == nome }&.valor.to_i }
      ponderado = apuradas.sum { |apurada| apurada.atividade.receita * apurada.percentuais.fetch(nome, 0) }
      Tributo.new(nome:, percentual: Rational(ponderado, receita), valor:)
    end

    # [RBT12 da alíquota, faixa, alíquota efetiva]. RBT12 zero vira R$ 1,00, só para achar a
    # alíquota (Res. CGSN 140/2018, art. 21, parágrafo único): sem isso a conta dividiria por zero.
    def self.faixa_e_aliquota(tabela, rbt12)
      rbt12 = 100 if rbt12.zero?
      faixa = faixa_da(tabela, rbt12)
      [rbt12, faixa, aliquota_efetiva(faixa, rbt12)]
    end

    # A faixa da RBT12. Acima do limite (o que acontece com a RBT12 anualizada no início de
    # atividade ou de 12 meses que não são o ano), vale a última faixa (Res. CGSN 140/2018, art. 22, § 5º).
    def self.faixa_da(tabela, rbt12) = tabela.faixas.find { |item| rbt12 <= centavos(item.ate) } || tabela.faixas.last

    # (RBT12 × alíquota nominal − parcela a deduzir) ÷ RBT12, com a RBT12 em centavos.
    def self.aliquota_efetiva(faixa, rbt12) = ((rbt12 * faixa.aliquota) - centavos(faixa.deduzir)) / rbt12

    # As tabelas de 2026 (para quem usava antes de existir mais de um ano). Ver Regras.tabelas.
    def self.tabelas = Regras.tabelas(Regras::DE_2026)

    # Reais (Rational, como vêm das tabelas) → centavos (Integer).
    def self.centavos(reais) = (reais * 100).round

    private_class_method :apurar, :das, :somar, :somar_um
  end
end
