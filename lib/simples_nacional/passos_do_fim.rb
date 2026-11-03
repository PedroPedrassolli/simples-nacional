# frozen_string_literal: true

module SimplesNacional
  # Os últimos passos da memória de cálculo: o que fica fora do DAS e o DAS do mês.
  module PassosDoFim
    def self.fora_do_das(estimativas)
      estimativas.map do |estimativa|
        Passos::Passo.new(titulo: "#{estimativa.tributo} fora do DAS", fonte: estimativa.fonte,
                          texto: [estimativa.texto, estimativa.falta].compact.join(" "))
      end
    end

    # O DAS do mês: a soma das receitas e do ICMS ou do ISS em valor fixo.
    def self.das(resultado)
      fixos = resultado.dados.valores_fixos
      return PassosDaAtividade.das_de_uma(resultado) if resultado.atividades.size == 1 && fixos.empty?

      fonte = fixos.empty? ? "LC 123/2006, art. 18, § 3º" : "LC 123/2006, art. 18, § 3º; #{ValoresFixos::FONTE}"
      soma = "#{parcelas(resultado).join(' + ')} = #{Formato.reais(resultado.das)}"
      Passos::Passo.new(titulo: "DAS estimado", fonte:, texto: "Soma das receitas: #{soma}.")
    end

    def self.parcelas(resultado)
      resultado.atividades.map { |apurada| Formato.reais(apurada.valor) } +
        resultado.dados.valores_fixos.map { |nome, valor| "#{Formato.reais(valor)} (#{nome} em valor fixo)" }
    end

    private_class_method :parcelas
  end
end
