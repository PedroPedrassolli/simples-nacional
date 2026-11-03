# frozen_string_literal: true

module SimplesNacional
  module ForaDoDas
    # ISS, ICMS, IBS e CBS fora do DAS: base × alíquota, menos os créditos (o ISS não tem crédito).
    module Locais
      FONTES = {
        "ISS" => "LC 123/2006, art. 20, §§ 1º e 1º-A; LC 116/2003, arts. 8º, II, e 8º-A",
        "ICMS" => "LC 123/2006, art. 20, §§ 1º e 1º-A; legislação do estado",
        "IBS" => "Res. CGSN 140/2018, arts. 12, 22-A e 40-C (redação da Res. CGSN 190/2026); LC 214/2025",
        "CBS" => "Res. CGSN 140/2018, arts. 22-A e 40-C (redação da Res. CGSN 190/2026); LC 214/2025"
      }.freeze

      DE_QUEM = { "ISS" => "do município (de 2% a 5%)", "ICMS" => "do estado", "IBS" => "do IBS",
                  "CBS" => "da CBS" }.freeze

      def self.iss(apuradas, informado) = estimar("ISS", apuradas, informado.aliquota_iss, 0)

      def self.icms(apuradas, informado)
        estimar("ICMS", apuradas, informado.aliquota_icms, informado.creditos_icms || 0)
      end

      def self.ibs(apuradas, informado) = estimar("IBS", apuradas, informado.aliquota_ibs, informado.creditos_ibs || 0)

      def self.cbs(apuradas, informado) = estimar("CBS", apuradas, informado.aliquota_cbs, informado.creditos_cbs || 0)

      def self.estimar(tributo, apuradas, aliquota, creditos)
        base = ForaDoDas.base(apuradas, tributo)
        return if base.zero?

        inicio = "#{Formato.frase(Formato.lista([tributo]))} de #{Formato.reais(base)} de receita não entra no DAS."
        if aliquota.nil?
          return Estimativa.new(tributo:, base:, valor: nil, texto: inicio, fonte: FONTES[tributo],
                                falta: "Informe a alíquota #{DE_QUEM[tributo]} para estimar.")
        end

        valor = [(base * aliquota).round(half: :up) - creditos, 0].max
        Estimativa.new(tributo:, base:, valor:, falta: nil, fonte: FONTES[tributo],
                       texto: "#{inicio} #{conta(tributo, base, aliquota, creditos, valor)}")
      end

      def self.conta(tributo, base, aliquota, creditos, valor)
        menos = creditos.zero? ? "" : " − #{Formato.reais(creditos)} de créditos"
        "Estimativa: #{Formato.reais(base)} × #{Formato.percentual(aliquota)}#{menos} = #{Formato.reais(valor)}" \
          "#{' (os créditos cobrem o imposto do mês)' if valor.zero? && creditos.positive?}." \
          "#{" Confira a alíquota do #{tributo} na legislação do seu município." if tributo == 'ISS'}"
      end

      private_class_method :estimar, :conta
    end

    # CPP do Anexo IV, paga na guia da Receita Federal (DCTFWeb), não no DAS.
    module Cpp
      FONTE = "LC 123/2006, art. 18, § 5º-C; Lei 8.212/1991, art. 22, I a III; Lei 10.666/2003, art. 10"
      PATRONAL = Rational(20, 100)

      def self.estimar(apuradas, informado)
        anexo_iv = apuradas.select { |apurada| apurada.tabela.numero == 4 }
        return if anexo_iv.empty?

        inicio = "No Anexo IV, a contribuição patronal ao INSS (CPP) não entra no DAS."
        falta = falta(informado)
        return Estimativa.new(tributo: "CPP", base: nil, valor: nil, texto: inicio, falta:, fonte: FONTE) if falta

        Estimativa.new(tributo: "CPP", base: nil, valor: valor(informado), falta: nil, fonte: FONTE,
                       texto: "#{inicio} #{conta(informado)}#{misturada(apuradas, anexo_iv)}")
      end

      def self.falta(informado)
        if informado.folha_empregados.nil? && informado.pro_labore.nil?
          return "Informe a folha dos empregados e o pró-labore do mês para estimar."
        end

        "Informe o RAT (1%, 2% ou 3%) para estimar." if informado.folha_empregados.to_i.positive? && informado.rat.nil?
      end

      def self.taxa(informado) = PATRONAL + (Rational(informado.rat.to_i, 100) * (informado.fap || 1))

      def self.valor(informado)
        ((informado.folha_empregados.to_i * taxa(informado)).round(half: :up) +
          (informado.pro_labore.to_i * PATRONAL).round(half: :up))
      end

      def self.conta(informado)
        rat = "#{informado.rat.to_i}% × FAP #{Formato.decimal(informado.fap || 1)}"
        "Estimativa: #{Formato.reais(informado.folha_empregados.to_i)} × (20% + #{rat}) + " \
          "#{Formato.reais(informado.pro_labore.to_i)} de pró-labore × 20% = #{Formato.reais(valor(informado))}."
      end

      # Com atividades de outros anexos, a conta acima usa a folha inteira.
      def self.misturada(apuradas, anexo_iv)
        return "" if apuradas.size == anexo_iv.size

        " A empresa também tem receita de outros anexos e a conta usa a folha inteira: confira com um contador " \
          "se a contribuição deve ser proporcional."
      end

      private_class_method :falta, :taxa, :valor, :conta, :misturada
    end
  end
end
