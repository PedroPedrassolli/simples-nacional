# frozen_string_literal: true

require "date"
require "yaml"

module SimplesNacional
  # Lê as tabelas dos Anexos I a V da Lei Complementar nº 123/2006 (data/anexos/*.yml).
  #
  # Cada arquivo precisa dizer de onde veio (fonte oficial) e desde quando vale
  # (vigência). Arquivo sem isso é recusado: número sem fonte não entra na conta.
  #
  #   SimplesNacional::Tabelas.todas[1].faixas.first
  #   # => #<data Faixa numero=1, ate=(180000/1), aliquota=(1/25), deduzir=(0/1)>
  #
  # Os valores viram Rational (frações exatas), nunca Float: 7,30% é 73/1000, e não
  # 0.07299999... A alíquota já vem dividida por 100.
  module Tabelas
    PASTA = File.expand_path("../../data/anexos", __dir__)

    CAMPOS = %w[anexo nome fonte redacao vigencia conferido_em faixas].freeze

    # Toda tabela do Simples tem 6 faixas de receita bruta em 12 meses.
    QUANTIDADE_DE_FAIXAS = 6

    # Dinheiro e percentual sempre como texto, com ponto e duas casas: "5940.00", "7.30".
    NUMERO = /\A\d+\.\d{2}\z/

    # Arquivo de tabela mal preenchido. A mensagem diz o arquivo e o problema.
    class TabelaInvalida < StandardError; end

    Faixa = Data.define(:numero, :ate, :aliquota, :deduzir)
    Anexo = Data.define(:numero, :nome, :fonte, :redacao, :vigencia, :conferido_em, :faixas)

    # Todas as tabelas da pasta, pelo número do anexo: { 1 => Anexo, 2 => Anexo, ... }
    def self.todas(pasta = PASTA)
      # O Dir[] já devolve os arquivos em ordem alfabética (anexo-1, anexo-2...).
      Dir[File.join(pasta, "*.yml")].to_h do |arquivo|
        anexo = ler(arquivo)
        [anexo.numero, anexo]
      end
    end

    def self.ler(arquivo)
      dados = YAML.safe_load_file(arquivo)
      problema = dados.is_a?(Hash) ? conferir_campos(dados) || conferir_faixas(dados["faixas"]) : "não é um mapa"
      raise TabelaInvalida, "#{File.basename(arquivo)}: #{problema}" if problema

      montar_anexo(dados)
    rescue Psych::DisallowedClass
      # Data sem aspas no YAML vira um objeto Date, que o safe_load não aceita.
      raise TabelaInvalida, "#{File.basename(arquivo)}: escreva as datas entre aspas, como \"2018-01-01\""
    end

    # Cada conferência devolve a mensagem do problema, ou nil se estiver tudo certo.
    def self.conferir_campos(dados)
      faltando = CAMPOS.select { |campo| dados[campo].to_s.strip.empty? }
      return "falta #{faltando.join(', ')}" if faltando.any?
      return "anexo precisa ser um número de 1 a 5" unless [1, 2, 3, 4, 5].include?(dados["anexo"])
      return "a fonte precisa ser um link https" unless dados["fonte"].to_s.start_with?("https://")

      "vigencia e conferido_em precisam ser datas (AAAA-MM-DD)" unless datas?(dados["vigencia"], dados["conferido_em"])
    end

    def self.datas?(*textos)
      textos.each { |texto| Date.iso8601(texto.to_s) }
      true
    rescue Date::Error
      false
    end

    def self.conferir_faixas(faixas)
      return "faixas precisa ser uma lista com #{QUANTIDADE_DE_FAIXAS} faixas" unless lista_de_faixas?(faixas)
      return "use números como \"5940.00\", entre aspas" unless numeros_validos?(faixas)

      "as faixas precisam estar em ordem crescente" unless em_ordem_crescente?(faixas)
    end

    def self.lista_de_faixas?(faixas)
      faixas.is_a?(Array) && faixas.size == QUANTIDADE_DE_FAIXAS && faixas.all?(Hash)
    end

    def self.numeros_validos?(faixas)
      valores = faixas.flat_map { |faixa| faixa.values_at("ate", "aliquota", "deduzir") }
      valores.all? { |valor| NUMERO.match?(valor.to_s) }
    end

    def self.em_ordem_crescente?(faixas)
      limites = faixas.map { |faixa| Rational(faixa["ate"]) }
      limites.each_cons(2).all? { |menor, maior| menor < maior }
    end

    def self.montar_anexo(dados)
      Anexo.new(numero: dados["anexo"], nome: dados["nome"], fonte: dados["fonte"], redacao: dados["redacao"],
                vigencia: Date.iso8601(dados["vigencia"]), conferido_em: Date.iso8601(dados["conferido_em"]),
                faixas: montar_faixas(dados["faixas"]))
    end

    def self.montar_faixas(faixas)
      faixas.each_with_index.map do |faixa, indice|
        Faixa.new(numero: indice + 1, ate: Rational(faixa["ate"]),
                  aliquota: Rational(faixa["aliquota"]) / 100, deduzir: Rational(faixa["deduzir"]))
      end
    end

    private_class_method :conferir_campos, :datas?, :conferir_faixas, :lista_de_faixas?, :numeros_validos?,
                         :em_ordem_crescente?, :montar_anexo, :montar_faixas
  end
end
