# frozen_string_literal: true

require "yaml"

module SimplesNacional
  # O DAS do Microempreendedor Individual (Simei): valores fixos por mês, que não dependem da
  # receita (LC 123/2006, art. 18-A; Res. CGSN 140/2018, arts. 100 a 101). Os valores, o
  # salário mínimo e os limites estão em data/mei.yml, com a fonte de cada um.
  #
  # Com a receita do ano, a calculadora confere o limite. Acima dele (art. 18-A, § 7º, III, e
  # § 10; Res. CGSN 140/2018, art. 115, §§ 8º e 9º):
  # - até 20%: o MEI vira ME no ano seguinte e paga, junto com o DAS de janeiro, a diferença
  #   sobre o excesso pelas alíquotas dos Anexos (aqui, a 1ª faixa do anexo da atividade);
  # - mais de 20%: o desenquadramento volta a janeiro (ou ao início) e as receitas do ano são
  #   apuradas como ME no PGDAS-D, com multa e juros.
  module Mei
    ARQUIVO = File.expand_path("../../data/mei.yml", __dir__)

    # anexos: o anexo da diferença sobre o excesso (indústria: o da indústria no ano, ver Regras).
    # tributos: o imposto local que o MEI paga (ICMS se é contribuinte do ICMS, ISS se do ISS).
    Atividade = Data.define(:codigo, :nome, :anexo, :locais)
    ATIVIDADES = {
      "comercio" => Atividade.new(codigo: "comercio", nome: "Comércio", anexo: 1, locais: ["ICMS"]),
      "industria" => Atividade.new(codigo: "industria", nome: "Indústria", anexo: :industria, locais: ["ICMS"]),
      "servicos" => Atividade.new(codigo: "servicos", nome: "Serviços", anexo: 3, locais: ["ISS"]),
      "comercio_servicos" => Atividade.new(codigo: "comercio_servicos", nome: "Comércio e serviços", anexo: nil,
                                           locais: %w[ICMS ISS])
    }.freeze

    LIMITE = 8_100_000
    LIMITE_POR_MES = 675_000
    LIMITE_TRANSPORTADOR = 25_160_000
    LIMITE_TRANSPORTADOR_POR_MES = Rational(2_096_667)
    INSS = Rational(5, 100)
    INSS_TRANSPORTADOR = Rational(12, 100)

    # valor: em centavos (Rational: a CBS e o IBS de 2027 têm milésimos de real).
    Tributo = Data.define(:nome, :valor)
    # limite e receita_ano em centavos; excesso: o que passou (0 se não passou); diferenca: a
    # estimativa do que pagar sobre o excesso (nil se não deu para calcular); situacao: texto.
    Limite = Data.define(:limite, :receita_ano, :excesso, :diferenca, :situacao)
    Resultado = Data.define(:periodo, :atividade, :transportador, :salario_minimo, :tributos, :das, :limite,
                            :atraso, :passos)

    def self.calcular(periodo:, atividade:, transportador: false, inicio: nil, receita_ano: nil, salario_minimo: nil,
                      pagamento: nil)
      periodo, regras = mes_e_regras(periodo)
      atividade = ATIVIDADES[atividade.to_s] || raise(Entrada::EntradaInvalida, "Escolha a atividade do MEI.")
      inicio = conferir_inicio(inicio, periodo)
      resultado = do_mes(periodo, atividade, transportador, salario_minimo(periodo.year, salario_minimo))
      limite = limite(regras, atividade, transportador:, inicio:, ano: periodo.year, receita_ano:)
      completar(resultado.with(limite:), Atraso.conferir(pagamento, periodo))
    end

    # O atraso (depende do DAS) e os passos (dependem de tudo).
    def self.completar(resultado, pagamento)
      resultado = resultado.with(atraso: Atraso.calcular(resultado.das, resultado.periodo, pagamento))
      resultado.with(passos: PassosDoMei.montar(resultado))
    end

    # Os tributos do mês e o DAS (sem o limite, o atraso e os passos, que vêm depois).
    def self.do_mes(periodo, atividade, transportador, minimo)
      tributos = tributos(periodo.year, atividade, transportador, minimo)
      Resultado.new(periodo:, atividade:, transportador:, salario_minimo: minimo, tributos:,
                    das: tributos.sum(&:valor).round(half: :up), limite: nil, atraso: nil, passos: [])
    end

    def self.mes_e_regras(texto)
      periodo = Entrada.mes(texto) || raise(Entrada::EntradaInvalida, "Informe o mês no formato AAAA-MM, como 2026-03.")
      regras = Regras.do_ano(periodo.year)
      raise Entrada::EntradaInvalida, "A calculadora do MEI usa as regras de 2026 a 2028." unless regras

      [periodo, regras]
    end

    def self.conferir_inicio(texto, periodo)
      return if texto.nil?

      inicio = Entrada.mes(texto) || raise(Entrada::EntradaInvalida, "Informe o início no formato AAAA-MM.")
      raise Entrada::EntradaInvalida, "O início das atividades não pode ser depois do mês." if inicio > periodo

      inicio
    end

    # O do decreto do ano ou, sem decreto ainda, o informado (em centavos).
    def self.salario_minimo(ano, informado)
      oficial = dados.dig("salario_minimo", ano, "valor")
      return (Rational(oficial) * 100).to_i if oficial

      if informado
        Entrada.conferir_valor(informado, "O salário mínimo", positivo: true)
        return informado
      end

      raise Entrada::EntradaInvalida, "O salário mínimo de #{ano} ainda não foi publicado: informe o valor para " \
                                      "estimar o INSS do MEI (5% do salário mínimo)."
    end

    def self.tributos(ano, atividade, transportador, minimo)
      inss = Tributo.new(nome: "INSS", valor: (minimo * (transportador ? INSS_TRANSPORTADOR : INSS)).round(half: :up))
      fixos = dados.dig("valores_fixos", ano).filter_map do |nome, valor|
        next if %w[ICMS ISS].include?(nome) && !atividade.locais.include?(nome)

        Tributo.new(nome:, valor: Rational(valor) * 100)
      end
      [inss, *fixos]
    end

    # O limite do ano (proporcional no ano de início) e o que fazer acima dele.
    def self.limite(regras, atividade, transportador:, inicio:, ano:, receita_ano:)
      limite = limite_do_ano(transportador, inicio, ano)
      return Limite.new(limite:, receita_ano: nil, excesso: 0, diferenca: nil, situacao: nil) if receita_ano.nil?

      Entrada.conferir_valor(receita_ano, "A receita do ano")
      excesso = [receita_ano - limite, 0].max
      if excesso.positive? && receita_ano <= limite * Sublimite::TOLERANCIA
        diferenca = diferenca(regras, atividade, excesso)
      end
      Limite.new(limite:, receita_ano:, excesso:, diferenca:,
                 situacao: situacao(limite, receita_ano, inicio&.year == ano))
    end

    def self.limite_do_ano(transportador, inicio, ano)
      return (transportador ? LIMITE_TRANSPORTADOR : LIMITE) unless inicio&.year == ano

      ((transportador ? LIMITE_TRANSPORTADOR_POR_MES : LIMITE_POR_MES) * (13 - inicio.month)).round
    end

    # Excesso × alíquota da 1ª faixa do anexo da atividade. Com comércio e serviços, depende da
    # receita de cada um: nil (a DASN-Simei pede as duas).
    def self.diferenca(regras, atividade, excesso)
      return if atividade.anexo.nil?

      numero = atividade.anexo == :industria ? regras.anexo_da_industria : atividade.anexo
      aliquota = Regras.tabelas(regras).fetch(numero).faixas.first.aliquota
      (excesso * aliquota).round(half: :up)
    end

    def self.situacao(limite, receita_ano, inicio)
      return :dentro if receita_ano <= limite
      return :ate_vinte_por_cento if receita_ano <= limite * Sublimite::TOLERANCIA

      inicio ? :desde_o_inicio : :desde_janeiro
    end

    def self.dados = @dados ||= YAML.safe_load_file(ARQUIVO)

    private_class_method :completar, :do_mes, :mes_e_regras, :conferir_inicio, :salario_minimo, :tributos, :limite,
                         :limite_do_ano, :diferenca, :situacao
  end
end
