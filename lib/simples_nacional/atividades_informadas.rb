# frozen_string_literal: true

module SimplesNacional
  # Confere as receitas que a pessoa informou (tipo, valor e qualificadores) e devolve a lista
  # de Atividades::Atividade. Os tipos e os qualificadores estão em Atividades.
  module AtividadesInformadas
    # Recebe [{ tipo: "revenda", receita: 1_000_000, opcoes: ["st_icms", "reducao_icms=40"] }, ...]
    # e devolve a lista de Atividade, ou levanta EntradaInvalida com a mensagem para a página.
    # A redução vai em %, depois do "=", com até 4 casas (de 0,0001% a 99,9999%; 100% é a isenção).
    def self.conferir(lista, regras)
      raise Entrada::EntradaInvalida, "Informe pelo menos uma receita do mês." unless lista.is_a?(Array) && lista.any?
      raise Entrada::EntradaInvalida, "Informe no máximo #{MAXIMO} receitas no mês." if lista.size > MAXIMO

      lista.each_with_index.map do |item, indice|
        conferir_uma(item, lista.size == 1 ? "do mês" : (indice + 1).to_s, regras)
      end
    end

    # Mais que isso não é um caso real e só deixaria a URL enorme.
    MAXIMO = 10

    def self.conferir_uma(item, numero, regras)
      item = item.to_h
      tipo = Atividades::TIPOS[item[:tipo].to_s]
      raise Entrada::EntradaInvalida, "Escolha o tipo da receita #{numero}." if tipo.nil?

      opcoes, reducoes = separar(Array(item[:opcoes]).map(&:to_s), numero)
      conferir_opcoes(tipo, opcoes, numero, regras)
      Entrada.conferir_valor(item[:receita], "A receita #{numero}", positivo: true)
      Atividades::Atividade.new(tipo:, receita: item[:receita], opcoes:, reducoes:)
    end

    PERCENTUAL = /\A\d{1,2}(?:\.\d{1,4})?\z/

    # ["st_icms", "reducao_iss=40"] → [["st_icms", "reducao_iss"], { "ISS" => 2/5 }]
    def self.separar(textos, numero)
      reducoes = {}
      codigos = textos.map do |texto|
        codigo, valor = texto.scrub.split("=", 2)
        reducoes[Atividades::REDUCOES[codigo]] = reducao(valor, numero) if Atividades::REDUCOES.key?(codigo)
        codigo
      end
      [codigos.uniq, reducoes]
    end

    def self.reducao(valor, numero)
      fracao = Rational(valor) / 100 if PERCENTUAL.match?(valor.to_s)
      return fracao if fracao&.positive?

      raise Entrada::EntradaInvalida, "Informe o percentual da redução da receita #{numero}, maior que 0% e menor " \
                                      "que 100% (100% é a isenção)."
    end

    def self.conferir_opcoes(tipo, opcoes, numero, regras)
      invalida = opcoes.find { |codigo| !tipo.opcoes.include?(codigo) }
      if invalida
        raise Entrada::EntradaInvalida, "A opção \"#{invalida}\" não vale para a receita #{numero} (#{tipo.nome})."
      end

      conferir_isencao_e_reducao(opcoes, numero)
      return unless opcoes.include?("ipi_mantido") && regras.anexo_da_industria == 2

      raise Entrada::EntradaInvalida, "O IPI mantido da Zona Franca só muda o anexo a partir de 2027: em " \
                                      "#{regras.ano}, a venda de produto industrializado já é do Anexo II."
    end

    # A isenção e a redução do mesmo imposto não andam juntas (a isenção já tira tudo).
    def self.conferir_isencao_e_reducao(opcoes, numero)
      [Atividades::DO_ESTADO, Atividades::DO_MUNICIPIO].each do |par|
        next unless (par - opcoes).empty?

        raise Entrada::EntradaInvalida, "Na receita #{numero}, marque isenção ou redução do mesmo imposto, não as duas."
      end
    end

    private_class_method :conferir_uma, :separar, :reducao, :conferir_opcoes, :conferir_isencao_e_reducao
  end
end
