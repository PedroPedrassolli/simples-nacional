# frozen_string_literal: true

module SimplesNacional
  # O passo "O que esta receita não paga no DAS": os tributos que o tipo de atividade e os
  # qualificadores tiram da conta (segregação), a CBS e o IBS de quem optou pelo regime
  # regular, e o ICMS do Anexo I no transporte e na comunicação.
  module PassoDosAjustes
    # [] quando a receita paga a divisão inteira.
    def self.montar(apurada, dados)
      motivos = motivos(apurada, dados)
      icms = icms_do_anexo_i(apurada)
      return [] if motivos.empty? && icms.nil?

      soma = "Soma dos percentuais desta receita: #{Formato.percentual(apurada.total, 4)}."
      fontes = [*motivos.map(&:last), icms&.last].compact.uniq.join("; ")
      [Passos::Passo.new(titulo: "O que esta receita não paga no DAS", fonte: fontes,
                         texto: [saem(motivos), icms&.first, soma].compact.join(" "))]
    end

    def self.saem(motivos)
      return if motivos.empty?

      "Saem da conta: #{Formato.juntar(motivos.map { |nomes, porque, _fonte| "#{Formato.lista(nomes)} (#{porque})" })}."
    end

    # [texto, fonte] do ICMS do Anexo I no transporte e na comunicação, ou nil.
    def self.icms_do_anexo_i(apurada)
      return unless apurada.atividade.tipo.icms_do_anexo_i && apurada.percentuais.key?("ICMS")

      ["Entra o ICMS do Anexo I na mesma faixa: #{Formato.percentual(apurada.percentuais['ICMS'], 4)}.",
       "Res. CGSN 140/2018, art. 25, § 1º, IX"]
    end

    # [[tributos, motivo, fonte], ...] só com os tributos que estavam na divisão.
    def self.motivos(apurada, dados)
      lista = [motivo_do_tipo(apurada.atividade.tipo), *motivos_das_opcoes(apurada.atividade, dados.regras),
               motivo_do_regime_regular(dados)]
      lista.compact.filter_map do |nomes, porque, fonte|
        nomes &= apurada.reparticao.keys
        [nomes, porque, fonte] if nomes.any?
      end
    end

    def self.motivos_das_opcoes(atividade, regras)
      atividade.opcoes.map do |codigo|
        opcao = Atividades.opcao(codigo, regras)
        [Atividades.tira_da_opcao(codigo, regras), opcao.motivo, opcao.fonte]
      end
    end

    def self.motivo_do_regime_regular(dados)
      return unless dados.ibs_cbs_fora

      [%w[CBS IBS], "pagos fora do DAS, no regime regular",
       "#{dados.regras.res}, arts. 22-A e 40-C"]
    end

    def self.motivo_do_tipo(tipo)
      return if tipo.tira.empty?

      porque = tipo.icms_do_anexo_i ? "transporte e comunicação pagam ICMS, e não ISS" : "locação de bens móveis"
      [tipo.tira, porque, tipo.fonte]
    end

    private_class_method :saem, :icms_do_anexo_i, :motivos, :motivos_das_opcoes, :motivo_do_regime_regular,
                         :motivo_do_tipo
  end
end
