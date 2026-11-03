# frozen_string_literal: true

module SimplesNacional
  # Segregação de receitas: como no PGDAS-D, cada receita do mês é informada separada, com o
  # tipo de atividade (que diz o anexo) e o que já foi pago fora do Simples (que tira
  # tributos da conta).
  #
  # LC 123/2006, art. 18, §§ 4º, 4º-A, 12 a 14; Res. CGSN 140/2018, art. 25.
  # https://www.planalto.gov.br/ccivil_03/leis/lcp/lcp123.htm (conferido em 02/11/2026)
  # https://normas.receita.fazenda.gov.br/sijut2consulta/link.action?idAto=92278 (conferido em 02/11/2026)
  module Atividades
    # anexo: 1 a 5, :fator_r (III ou V) ou :industria (depende do ano, ver Regras).
    # tira: tributos que a atividade nunca paga no DAS. icms_do_anexo_i: soma o ICMS do Anexo I.
    # opcoes: os qualificadores que fazem sentido para a atividade.
    Tipo = Data.define(:codigo, :nome, :anexo, :tira, :icms_do_anexo_i, :opcoes, :fonte)

    def self.tipo(codigo, nome, anexo, opcoes, fonte, tira: [], icms_do_anexo_i: false)
      Tipo.new(codigo:, nome:, anexo:, tira:, icms_do_anexo_i:, opcoes:, fonte:)
    end

    MERCADORIAS = %w[st_icms monofasico exportacao].freeze
    SERVICOS = %w[iss_retido exportacao].freeze

    TIPOS = [
      tipo("revenda", "Revenda de mercadorias", 1, MERCADORIAS, "LC 123/2006, art. 18, § 4º, I"),
      tipo("industria", "Venda de produtos fabricados pela empresa", :industria, [*MERCADORIAS, "ipi_mantido"],
           "LC 123/2006, art. 18, § 4º, II"),
      tipo("servicos_3", "Serviços do Anexo III", 3, SERVICOS, "LC 123/2006, art. 18, § 4º, III, e § 5º-B"),
      tipo("servicos_4", "Serviços do Anexo IV (obras, limpeza, vigilância, advocacia)", 4, SERVICOS,
           "LC 123/2006, art. 18, § 4º, IV, e § 5º-C"),
      tipo("servicos_5", "Serviços do Anexo V", 5, SERVICOS, "LC 123/2006, art. 18, § 4º, IV, e § 5º-I"),
      tipo("fator_r", "Serviços do Anexo III ou V, pelo Fator R", :fator_r, SERVICOS,
           "LC 123/2006, art. 18, §§ 5º-J, 5º-K e 5º-M"),
      # Anexo III "deduzida a parcela correspondente ao ISS" (art. 18, § 4º, V).
      tipo("locacao", "Locação de bens móveis", 3, [], "LC 123/2006, art. 18, § 4º, V", tira: ["ISS"]),
      # Anexo III sem o ISS e com o ICMS do Anexo I (Res. CGSN 140/2018, art. 25, § 1º, IX).
      tipo("transporte", "Transporte intermunicipal ou interestadual, ou comunicação", 3, ["st_icms"],
           "Res. CGSN 140/2018, art. 25, § 1º, IX", tira: ["ISS"], icms_do_anexo_i: true)
    ].to_h { |tipo| [tipo.codigo, tipo] }.freeze

    # O que a pessoa informou, já conferido: tipo (Tipo), receita em centavos e os códigos
    # dos qualificadores.
    Atividade = Data.define(:tipo, :receita, :opcoes) do
      def exportacao? = opcoes.include?("exportacao")
    end

    # nome: para o formulário; motivo: curto, para o passo a passo.
    Opcao = Data.define(:nome, :motivo, :fonte)

    # [nome, motivo, base legal] de cada qualificador; %<res>s é a Resolução do ano (ver Regras).
    OPCOES = {
      "st_icms" => ["ICMS já pago por substituição tributária ou antecipação",
                    "já pago por substituição tributária ou antecipação",
                    "LC 123/2006, art. 18, § 4º-A, I; %<res>s, art. 25, § 8º"],
      "monofasico" => [nil, "tributação concentrada (monofásica)",
                       "LC 123/2006, art. 18, § 4º-A, I; %<res>s, art. 25, § 6º"],
      "iss_retido" => ["ISS retido pelo tomador", "retido pelo tomador do serviço",
                       "LC 123/2006, art. 18, § 4º-A, II; %<res>s, art. 25, § 9º"],
      "exportacao" => ["Exportação", "exportação",
                       "LC 123/2006, art. 18, §§ 4º-A, IV, e 14; %<res>s, arts. 23 e 25, § 3º"],
      "ipi_mantido" => ["Produto com IPI mantido (Zona Franca de Manaus)", "IPI mantido", "%<res>s, art. 25, § 1º, II"]
    }.freeze

    # Nome, motivo e base legal de um qualificador. O nome do monofásico muda em 2027.
    def self.opcao(codigo, regras)
      nome, motivo, fonte = OPCOES.fetch(codigo)
      Opcao.new(nome || nome_do_monofasico(regras), motivo, format(fonte, res: regras.res))
    end

    def self.nome_do_monofasico(regras)
      return "PIS/Pasep e Cofins monofásicos (tributação concentrada)" if regras.tira_no_monofasico.include?("Cofins")

      "IBS e CBS com tributação concentrada (monofásica)"
    end

    # Tributos que saem da conta da atividade: os do tipo e os dos qualificadores.
    def self.tira(atividade, regras)
      (atividade.tipo.tira + atividade.opcoes.flat_map { |codigo| tira_da_opcao(codigo, regras) }).uniq
    end

    def self.tira_da_opcao(codigo, regras)
      case codigo
      when "st_icms" then ["ICMS"]
      when "monofasico" then regras.tira_no_monofasico
      when "iss_retido" then ["ISS"]
      when "exportacao" then regras.tira_na_exportacao
      else []
      end
    end

    # O número do anexo da atividade. fator_r: o anexo que o Fator R deu (3 ou 5).
    def self.anexo(atividade, regras, fator_r)
      case atividade.tipo.anexo
      when :fator_r then fator_r
      when :industria then atividade.opcoes.include?("ipi_mantido") ? 2 : regras.anexo_da_industria
      else atividade.tipo.anexo
      end
    end

    # Recebe [{ tipo: "revenda", receita: 1_000_000, opcoes: ["st_icms"] }, ...] e devolve
    # a lista de Atividade, ou levanta EntradaInvalida com a mensagem para a página.
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
      tipo = TIPOS[item[:tipo].to_s] || raise(Entrada::EntradaInvalida, "Escolha o tipo da receita #{numero}.")
      opcoes = Array(item[:opcoes]).map(&:to_s).uniq
      conferir_opcoes(tipo, opcoes, numero, regras)
      Entrada.conferir_valor(item[:receita], "A receita #{numero}", positivo: true)
      Atividade.new(tipo:, receita: item[:receita], opcoes:)
    end

    def self.conferir_opcoes(tipo, opcoes, numero, regras)
      invalida = opcoes.find { |codigo| !tipo.opcoes.include?(codigo) }
      if invalida
        raise Entrada::EntradaInvalida,
              "A opção \"#{invalida}\" não vale para a receita #{numero} (#{tipo.nome})."
      end
      return unless opcoes.include?("ipi_mantido") && regras.anexo_da_industria == 2

      raise Entrada::EntradaInvalida, "O IPI mantido da Zona Franca só muda o anexo a partir de 2027: em " \
                                      "#{regras.ano}, a venda de produto industrializado já é do Anexo II."
    end

    private_class_method :tipo, :nome_do_monofasico, :conferir_uma, :conferir_opcoes
  end
end
