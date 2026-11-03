# frozen_string_literal: true

module SimplesNacional
  # O passo "O que esta receita não paga no DAS": os tributos que o tipo de atividade e os
  # qualificadores tiram da conta (segregação), o ICMS ou o ISS pago em valor fixo, a CBS e o
  # IBS de quem optou pelo regime regular, o imposto que vem de outro anexo (transporte e
  # atividade com IPI e ISS) e as reduções dadas pelo estado ou pelo município.
  module PassoDosAjustes
    # [] quando a receita paga a divisão inteira.
    def self.montar(apurada, dados)
      motivos = motivos(apurada, dados)
      extras = [de_outro_anexo(apurada), *reducoes(apurada, dados)].compact
      return [] if motivos.empty? && extras.empty?

      [Passos::Passo.new(titulo: "O que esta receita não paga no DAS", fonte: fontes(motivos, extras),
                         texto: [saem(motivos), *extras.map(&:first), soma(apurada)].compact.join(" "))]
    end

    def self.fontes(motivos, extras) = [*motivos.map(&:last), *extras.map(&:last)].uniq.join("; ")

    def self.soma(apurada) = "Soma dos percentuais desta receita: #{Formato.percentual(apurada.total, 4)}."

    def self.saem(motivos)
      return if motivos.empty?

      "Saem da conta: #{Formato.juntar(motivos.map { |nomes, porque, _fonte| "#{Formato.lista(nomes)} (#{porque})" })}."
    end

    # [texto, fonte] do imposto que vem de outro anexo, na mesma faixa, ou nil.
    def self.de_outro_anexo(apurada)
      tributo, numero = apurada.atividade.tipo.de_outro_anexo.first
      return unless tributo && apurada.reparticao.key?(tributo)

      ["Entra o #{tributo} do Anexo #{Passos.romano(numero)} na mesma faixa: " \
       "#{Formato.percentual(apurada.reparticao[tributo], 4)}.", apurada.atividade.tipo.fonte]
    end

    # [[texto, fonte], ...] das reduções de ICMS e de ISS que ficaram na conta.
    def self.reducoes(apurada, dados)
      apurada.atividade.reducoes.filter_map do |tributo, fracao|
        next unless apurada.percentuais.key?(tributo)

        reducao(apurada, tributo, fracao, Atividades.opcao(Atividades::REDUCOES.key(tributo), dados.regras))
      end
    end

    def self.reducao(apurada, tributo, fracao, opcao)
      ["O #{tributo} tem redução de #{Formato.percentual(fracao)} (#{opcao.motivo}): " \
       "#{Formato.percentual(apurada.reparticao[tributo], 4)} × (1 − #{Formato.percentual(fracao)}) = " \
       "#{Formato.percentual(apurada.percentuais[tributo], 4)}.", opcao.fonte]
    end

    # [[tributos, motivo, fonte], ...] só com os tributos que estavam na divisão.
    def self.motivos(apurada, dados)
      lista = [motivo_do_tipo(apurada.atividade.tipo), *motivos_das_opcoes(apurada.atividade, dados.regras),
               motivo_do_valor_fixo(dados), motivo_do_regime_regular(dados)]
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

    def self.motivo_do_valor_fixo(dados)
      return if dados.valores_fixos.empty?

      [dados.valores_fixos.keys, "pago em valor fixo, somado ao DAS no fim", ValoresFixos::FONTE]
    end

    def self.motivo_do_regime_regular(dados)
      return unless dados.ibs_cbs_fora

      [%w[CBS IBS], "pagos fora do DAS, no regime regular",
       "#{dados.regras.res}, arts. 22-A e 40-C"]
    end

    def self.motivo_do_tipo(tipo)
      return if tipo.tira.empty?

      [tipo.tira, tipo.motivo, tipo.fonte]
    end

    private_class_method :fontes, :soma, :reducao, :saem, :de_outro_anexo, :reducoes, :motivos, :motivos_das_opcoes,
                         :motivo_do_valor_fixo, :motivo_do_regime_regular, :motivo_do_tipo
  end
end
