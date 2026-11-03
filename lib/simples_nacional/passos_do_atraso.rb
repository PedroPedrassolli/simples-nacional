# frozen_string_literal: true

module SimplesNacional
  # O passo "Multa e juros" (ver Atraso), no Simples e no MEI.
  module PassosDoAtraso
    # nil sem data de pagamento.
    def self.passo(atraso)
      return if atraso.nil?

      Passos::Passo.new(titulo: "Multa e juros", fonte: Atraso::FONTE, texto: texto(atraso))
    end

    def self.texto(atraso)
      vencimento = "O DAS vence em #{Formato.data(atraso.vencimento)} (dia 20 do mês seguinte ou o dia útil depois)."
      return "#{vencimento} Pago até essa data, não há multa nem juros." if atraso.dias.zero?

      [vencimento, multa(atraso), juros(atraso), total(atraso)].join(" ")
    end

    def self.total(atraso)
      das = atraso.total - atraso.multa - atraso.juros
      "Total a pagar: #{Formato.reais(das)} + #{Formato.reais(atraso.multa)} + #{Formato.reais(atraso.juros)} = " \
        "#{Formato.reais(atraso.total)}."
    end

    def self.multa(atraso)
      dias = atraso.dias == 1 ? "1 dia" : "#{atraso.dias} dias"
      limite = atraso.multa_percentual == Atraso::MULTA_MAXIMA ? ", limitada a 20%" : ""
      "Pago em #{Formato.data(atraso.pagamento)}: #{dias} de atraso. Multa de mora: 0,33% × #{atraso.dias} = " \
        "#{Formato.percentual(atraso.multa_percentual)}#{limite}, ou #{Formato.reais(atraso.multa)}."
    end

    def self.juros(atraso)
      return "Pago no mesmo mês do vencimento, não há juros de mora." if atraso.juros_percentual.zero?

      partes = []
      if atraso.meses_de_juros.any?
        partes << "Selic de #{periodo_da_selic(atraso.meses_de_juros)} (#{Formato.percentual(atraso.selic)})"
      end
      partes << "1% do mês do pagamento"
      "Juros de mora: #{Formato.juntar(partes)} = #{Formato.percentual(atraso.juros_percentual)}, ou " \
        "#{Formato.reais(atraso.juros)}."
    end

    def self.periodo_da_selic(meses)
      primeiro, ultimo = [meses.first, meses.last].map { |mes| Formato.mes(Entrada.mes(mes)) }
      meses.size == 1 ? primeiro : "#{primeiro} a #{ultimo}"
    end

    private_class_method :texto, :total, :multa, :juros, :periodo_da_selic
  end
end
