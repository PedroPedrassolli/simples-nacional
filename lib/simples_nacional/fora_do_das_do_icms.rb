# frozen_string_literal: true

module SimplesNacional
  module ForaDoDas
    # O ICMS que a empresa do Simples paga fora do DAS como qualquer outra: o da substituição
    # tributária (quando ela é a substituta) e o diferencial de alíquota das compras de outros
    # estados (LC 123/2006, art. 13, § 1º, XIII, e § 5º).
    module DoIcms
      FONTE = {
        "ICMS-ST" => "LC 123/2006, art. 13, § 1º, XIII, a, e § 5º; Convênio ICMS 142/2018, cláusulas décima " \
                     "primeira, § 1º, e décima terceira, § 1º",
        "DIFAL" => "LC 123/2006, art. 13, § 1º, XIII, g, 2, e h, e § 5º"
      }.freeze

      # A estimativa sem valor, dizendo o primeiro campo que falta; nil quando não falta nenhum.
      def self.falta(tributo, informado, base, campos, inicio)
        campo = campos.find { |nome| informado.public_send(nome).nil? }
        return if campo.nil?

        Estimativa.new(tributo:, base:, valor: nil, texto: inicio, fonte: FONTE.fetch(tributo),
                       falta: "Informe #{NOMES.fetch(campo).sub(/\A./, &:downcase)} para estimar.")
      end
    end

    # ICMS por substituição tributária de quem vende como substituto: o imposto pela alíquota
    # interna do destino sobre a base com a MVA, menos o ICMS da operação própria. Para o
    # remetente do Simples, vale a MVA das operações internas (a original, sem ajuste) e o ICMS
    # próprio deduzido é o da alíquota interestadual (Convênio ICMS 142/2018, cláusula
    # décima primeira, § 1º, e cláusula décima terceira, § 1º; LC 123/2006, art. 13, § 1º, XIII, a,
    # e § 5º). Na operação interna, a própria é a alíquota interna do estado.
    # https://www.confaz.fazenda.gov.br/legislacao/convenios/2018/CV142_18 (conferido em 03/11/2026)
    module Substituicao
      INICIO = "O ICMS da substituição tributária (a empresa é a substituta) é pago fora do DAS."
      CAMPOS = %i[st_mva st_aliquota_interna st_aliquota_propria].freeze

      def self.estimar(informado)
        return if informado.st_valor.nil?

        falta = DoIcms.falta("ICMS-ST", informado, informado.st_valor, CAMPOS, INICIO)
        return falta if falta

        base, propria, valor = conta(informado)
        Estimativa.new(tributo: "ICMS-ST", base: base.round(half: :up), valor:, falta: nil,
                       fonte: DoIcms::FONTE.fetch("ICMS-ST"),
                       texto: "#{INICIO} #{texto(informado, base, propria, valor)}")
      end

      # A base com a MVA, o ICMS próprio e o imposto (nunca negativo).
      def self.conta(informado)
        base = (informado.st_valor + informado.st_ipi.to_i) * (1 + informado.st_mva)
        propria = (informado.st_valor * informado.st_aliquota_propria).round(half: :up)
        [base, propria, [(base * informado.st_aliquota_interna).round(half: :up) - propria, 0].max]
      end

      def self.texto(informado, base, propria, valor)
        "Base: (#{Formato.reais(informado.st_valor)} + #{Formato.reais(informado.st_ipi.to_i)} de IPI e encargos) × " \
          "(1 + #{Formato.percentual(informado.st_mva)} de MVA) = #{Formato.reais(base)}. Imposto: " \
          "#{Formato.reais(base)} × #{Formato.percentual(informado.st_aliquota_interna)} − #{Formato.reais(propria)} " \
          "(#{Formato.percentual(informado.st_aliquota_propria)} da operação própria) = #{Formato.reais(valor)}."
      end

      private_class_method :conta, :texto
    end

    # Diferencial de alíquota nas compras de outros estados (para uso, consumo, ativo ou com
    # antecipação sem encerramento): valor × (alíquota interna − interestadual), com as alíquotas
    # das empresas fora do Simples e sem agregar valor (LC 123/2006, art. 13, § 1º, XIII, g, 2,
    # e h, e § 5º).
    module Difal
      INICIO = "O diferencial de alíquota do ICMS nas compras de outros estados é pago fora do DAS."
      CAMPOS = %i[difal_aliquota_interna difal_aliquota_interestadual].freeze

      def self.estimar(informado)
        compras = informado.difal_valor
        return if compras.nil?

        falta = DoIcms.falta("DIFAL", informado, compras, CAMPOS, INICIO)
        return falta if falta

        interna = informado.difal_aliquota_interna
        interestadual = informado.difal_aliquota_interestadual
        valor = (compras * [interna - interestadual, 0].max).round(half: :up)
        Estimativa.new(tributo: "DIFAL", base: compras, valor:, falta: nil, fonte: DoIcms::FONTE.fetch("DIFAL"),
                       texto: "#{INICIO} Estimativa: #{Formato.reais(compras)} × (#{Formato.percentual(interna)} − " \
                              "#{Formato.percentual(interestadual)}) = #{Formato.reais(valor)}.")
      end
    end
  end
end
