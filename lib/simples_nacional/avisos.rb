# frozen_string_literal: true

module SimplesNacional
  # O texto do passo "Mês a mês": o que a calculadora somou.
  module PassosDoHistorico
    def self.texto(dados)
      partes = [rbt12(dados, dados.historico), exportacao_e_folha(dados),
                "Receita de #{dados.periodo.year} até o mês anterior: #{Formato.reais(dados.receita_ano)}."]
      if dados.regras.rbt12_sem_o_mes_anterior
        partes << "A partir de 2027, a RBT12 são os 12 meses antes do mês anterior ao de apuração."
      end
      partes.compact.join(" ")
    end

    def self.exportacao_e_folha(dados)
      partes = []
      exportacao = dados.exportacao.informada
      partes << "Exportação na mesma janela: #{Formato.reais(exportacao)}." if exportacao&.positive?
      partes << "Folha de salários na mesma janela: #{Formato.reais(dados.folha.informada)}." if dados.folha
      partes.join(" ") if partes.any?
    end

    def self.rbt12(dados, meses)
      return "Ainda não há meses de atividade na janela da RBT12." if meses.empty?

      quantos = meses.size == 1 ? Formato.mes(meses.first) : "#{Formato.mes(meses.first)} a #{Formato.mes(meses.last)}"
      "RBT12 (soma de #{quantos}): #{Formato.reais(dados.interno.informada.to_i)}."
    end

    private_class_method :rbt12, :exportacao_e_folha
  end

  # Frases curtas para o topo do resultado, quando algo não segue a conta normal.
  module Avisos
    def self.montar(resultado)
      dados = resultado.dados
      locais = PassoDoSublimite.locais(resultado)
      [*(locais.any? ? dos_locais(dados, locais) : []), *limites(dados), LimiteDaExportacao.aviso(dados),
       *ValoresFixos.avisos(dados), *atraso(resultado.atraso)].compact
    end

    # Passou do limite do mercado interno ou do limite extra da exportação (nil quando não passou).
    def self.limites(dados)
      [(limite(dados) if dados.situacao.exclusao), (limite_da_exportacao(dados) if dados.situacao_exportacao.exclusao)]
    end

    def self.limite_da_exportacao(dados)
      "A receita de exportação do ano passou do limite extra de #{Formato.reais(dados.situacao_exportacao.limite)}: " \
        "a empresa sai do Simples #{PassoDoLimite.saida(dados.situacao_exportacao.exclusao, dados.periodo.year)}. " \
        "Veja o passo a passo."
    end

    # A Selic de algum mês de juros ainda não saiu: os juros ficam sem esses meses.
    def self.atraso(atraso)
      return [] if atraso.nil? || atraso.sem_selic.empty?

      meses = atraso.sem_selic.map { |mes| Formato.mes(Entrada.mes(mes)) }
      ["A Selic de #{Formato.juntar(meses)} ainda não foi publicada: os juros de mora estão sem " \
       "#{meses.size == 1 ? 'esse mês' : 'esses meses'} e vão ficar um pouco maiores."]
    end

    def self.dos_locais(dados, locais)
      situacao = dados.situacao
      [(fora(locais) if situacao.local == :fora), (majorado(locais) if situacao.fracao_sublimite.positive?),
       (impedimento(dados, locais) if impedimento?(dados))].compact
    end

    def self.fora(locais)
      quem = { "ICMS" => "do estado", "ISS" => "do município", "IBS" => "do IBS" }.values_at(*locais)
      "#{Formato.frase(Formato.lista(locais))} deste mês não #{locais.size == 1 ? 'entra' : 'entram'} no DAS: " \
        "#{locais.size == 1 ? 'é pago' : 'são pagos'} à parte, pelas regras normais #{Formato.juntar(quem)}. " \
        "A estimativa está em \"Fora do DAS\"."
    end

    def self.majorado(locais)
      "Parte da receita do mês passou do sublimite: #{Formato.lista(locais)} dessa parte " \
        "#{locais.size == 1 ? 'segue' : 'seguem'} outra regra. " \
        "Veja o passo a passo."
    end

    # A partir de 2027 não há percentual maior: só o aviso de quando o impedimento começa.
    def self.impedimento?(dados)
      !dados.regras.majora_excesso && %i[pouco_acima muito_acima].include?(dados.situacao.motivo)
    end

    def self.impedimento(dados, locais)
      quando = if dados.situacao.motivo == :muito_acima
                 "a partir do mês seguinte"
               else
                 "em 1º de janeiro de #{dados.periodo.year + 1}"
               end
      "A receita do ano passou do sublimite: #{Formato.lista(locais)} #{locais.size == 1 ? 'sai' : 'saem'} do DAS " \
        "#{quando}."
    end

    def self.limite(dados)
      "A receita do ano passou do limite de #{Formato.reais(dados.situacao.limite)}: a empresa sai do Simples " \
        "#{PassoDoLimite.saida(dados.situacao.exclusao, dados.periodo.year)}. Veja o passo a passo."
    end

    private_class_method :dos_locais, :fora, :majorado, :impedimento?, :impedimento, :limite, :limite_da_exportacao,
                         :atraso, :limites
  end
end
