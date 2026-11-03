# frozen_string_literal: true

require "date"
require "json"
require "yaml"

module SimplesNacional
  # DAS pago depois do vencimento: multa e juros de mora, como no imposto de renda (LC 123/2006,
  # art. 35; Res. CGSN 140/2018, art. 40, § 2º; Lei 9.430/1996, arts. 5º, § 3º, e 61).
  #
  # - Vencimento: dia 20 do mês seguinte ao de apuração; sem expediente bancário nesse dia, o
  #   dia útil seguinte (Res. CGSN 140/2018, art. 40, caput e § 3º).
  # - Multa de mora: 0,33% por dia, do dia seguinte ao vencimento até o dia do pagamento,
  #   limitada a 20% (Lei 9.430/1996, art. 61, caput e §§ 1º e 2º).
  # - Juros de mora: a Selic acumulada de cada mês, do mês seguinte ao do vencimento até o mês
  #   anterior ao do pagamento, mais 1% no mês do pagamento (art. 61, § 3º). Pago no mesmo mês
  #   do vencimento, não há juros.
  # https://www.planalto.gov.br/ccivil_03/leis/l9430.htm (conferido em 03/11/2026)
  # https://normas.receita.fazenda.gov.br/sijut2consulta/link.action?idAto=92278 (conferido em 03/11/2026)
  module Atraso
    ARQUIVO = File.expand_path("../../data/selic.yml", __dir__)
    FONTE = "LC 123/2006, art. 35; Res. CGSN 140/2018, art. 40, §§ 2º e 3º; Lei 9.430/1996, arts. 5º, § 3º, e 61"

    MULTA_POR_DIA = Rational(33, 10_000)
    MULTA_MAXIMA = Rational(20, 100)
    JUROS_DO_MES_DO_PAGAMENTO = Rational(1, 100)

    # Feriados nacionais de data fixa: 1º/1, 21/4, 1º/5, 7/9, 2/11, 15/11 e 25/12 (Lei 662/1949,
    # art. 1º, na redação da Lei 10.607/2002), 12/10 (Lei 6.802/1980) e 20/11 (Lei 14.759/2023).
    # Os dias sem expediente bancário que mudam de data (carnaval, Sexta-Feira Santa e Corpus
    # Christi) não caem no dia 20 nem no dia útil seguinte de 2026 a 2029 (um teste confere).
    FERIADOS = [[1, 1], [4, 21], [5, 1], [9, 7], [10, 12], [11, 2], [11, 15], [11, 20], [12, 25]].freeze

    # Datas: Date. dias: dias de atraso. selic: soma das taxas dos meses de juros (Rational).
    # Dinheiro em centavos. sem_selic: meses de juros cuja Selic ainda não foi publicada.
    Resultado = Data.define(:vencimento, :pagamento, :dias, :multa_percentual, :multa, :selic, :juros_percentual,
                            :juros, :total, :meses_de_juros, :sem_selic)

    # "2026-12-21" → Date; nil se vazio. Levanta EntradaInvalida se não for uma data.
    def self.conferir(texto, periodo)
      return if texto.nil?

      data = data(texto)
      raise Entrada::EntradaInvalida, "Informe a data do pagamento no formato AAAA-MM-DD, como 2026-12-21." unless data
      unless data > fim_do_mes(periodo) && data.year <= periodo.year + 10
        raise Entrada::EntradaInvalida, "A data do pagamento precisa ser depois do mês de apuração " \
                                        "(#{Formato.mes(periodo)}) e no máximo 10 anos depois."
      end

      data
    end

    def self.data(texto)
      ano, mes, dia = /\A(\d{4})-(\d{2})-(\d{2})\z/.match(texto.to_s.scrub)&.captures&.map(&:to_i)
      Date.new(ano, mes, dia) if ano && Date.valid_date?(ano, mes, dia)
    end

    def self.fim_do_mes(periodo) = periodo.next_month - 1

    # Vencimento do DAS do mês de apuração.
    def self.vencimento(periodo)
      dia = periodo.next_month + 19
      dia += 1 until util?(dia)
      dia
    end

    def self.util?(data) = !data.saturday? && !data.sunday? && !FERIADOS.include?([data.month, data.day])

    # nil sem data de pagamento. valor: o DAS em centavos.
    def self.calcular(valor, periodo, pagamento)
      return if pagamento.nil?

      vencimento = vencimento(periodo)
      percentuais = percentuais(vencimento, pagamento)
      multa, juros = percentuais.values_at(:multa_percentual, :juros_percentual).map do |percentual|
        (valor * percentual).round(half: :up)
      end
      Resultado.new(vencimento:, pagamento:, multa:, juros:, total: valor + multa + juros, **percentuais)
    end

    # Os dias de atraso, os percentuais de multa e de juros e os meses de Selic (não dependem do valor).
    def self.percentuais(vencimento, pagamento)
      dias = [(pagamento - vencimento).to_i, 0].max
      meses = meses_de_juros(vencimento, pagamento)
      selic = meses.sum { |mes| taxas.fetch(mes, 0) }
      { dias:, multa_percentual: [MULTA_POR_DIA * dias, MULTA_MAXIMA].min, meses_de_juros: meses, selic:,
        juros_percentual: selic + juros_do_mes_do_pagamento(vencimento, pagamento),
        sem_selic: meses.reject { |mes| taxas.key?(mes) } }
    end

    # O 1% só entra quando o pagamento é num mês depois do vencimento (pago no mesmo mês, não há juros).
    def self.juros_do_mes_do_pagamento(vencimento, pagamento)
      pagamento.strftime("%Y-%m") > vencimento.strftime("%Y-%m") ? JUROS_DO_MES_DO_PAGAMENTO : 0
    end

    # Do mês seguinte ao do vencimento até o mês anterior ao do pagamento, como "AAAA-MM".
    def self.meses_de_juros(vencimento, pagamento)
      mes = Date.new(vencimento.year, vencimento.month, 1).next_month
      ultimo = Date.new(pagamento.year, pagamento.month, 1).prev_month
      meses = []
      while mes <= ultimo
        meses << mes.strftime("%Y-%m")
        mes = mes.next_month
      end
      meses
    end

    # { "2026-03" => Rational(121, 10_000) } do data/selic.yml, lido uma vez só.
    def self.taxas = @taxas ||= ler(ARQUIVO)

    def self.ler(arquivo)
      YAML.safe_load_file(arquivo)["meses"].to_h { |mes, taxa| [mes, Rational(taxa) / 100] }
    end

    # O data/selic.yml a partir da resposta da API do Banco Central
    # ([{"data":"01/01/2026","valor":"1.16"}, ...]). Usado pelo workflow mensal.
    def self.yaml_da_serie(json, conferido_em)
      meses = JSON.parse(json).to_h do |linha|
        dia, mes, ano = linha.fetch("data").split("/")
        raise ArgumentError, "data inesperada: #{linha}" unless dia == "01" && /\A\d+\.\d+\z/.match?(linha["valor"])

        ["#{ano}-#{mes}", linha["valor"]]
      end
      cabecalho = File.read(ARQUIVO, encoding: "UTF-8")[/\A(?:#.*\n)+/]
      linhas = meses.sort.map { |mes, taxa| %(  "#{mes}": "#{taxa}") }
      "#{cabecalho}fonte: https://api.bcb.gov.br/dados/serie/bcdata.sgs.4390/dados?formato=json\n" \
        "conferido_em: \"#{conferido_em}\"\nmeses:\n#{linhas.join("\n")}\n"
    end

    private_class_method :data, :fim_do_mes, :percentuais, :juros_do_mes_do_pagamento, :meses_de_juros, :ler
  end
end
