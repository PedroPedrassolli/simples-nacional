# frozen_string_literal: true

module SimplesNacional
  # Segregação de receitas: como no PGDAS-D, cada receita do mês é informada separada, com o
  # tipo de atividade (que diz o anexo) e o que já foi pago fora do Simples (que tira
  # tributos da conta).
  #
  # LC 123/2006, art. 18, §§ 4º, 4º-A, 12 a 14, 20 e 20-A; Res. CGSN 140/2018, arts. 25 e 35.
  # https://www.planalto.gov.br/ccivil_03/leis/lcp/lcp123.htm (conferido em 03/11/2026)
  # https://normas.receita.fazenda.gov.br/sijut2consulta/link.action?idAto=92278 (conferido em 03/11/2026)
  module Atividades
    # anexo: 1 a 5, :fator_r (III ou V) ou :industria (depende do ano, ver Regras).
    # tira: tributos que a atividade nunca paga no DAS; motivo: por que (para o passo a passo).
    # de_outro_anexo: tributo que vem de outro anexo, na mesma faixa ({ "ICMS" => 1 }).
    # opcoes: os qualificadores que fazem sentido para a atividade.
    Tipo = Data.define(:codigo, :nome, :anexo, :tira, :motivo, :de_outro_anexo, :opcoes, :fonte)

    def self.tipo(codigo, nome, anexo, opcoes, fonte, tira: [], motivo: nil, de_outro_anexo: {})
      Tipo.new(codigo:, nome:, anexo:, tira:, motivo:, de_outro_anexo:, opcoes:, fonte:)
    end

    # Isenção ou redução que o estado (ICMS) ou o município (ISS) dá às ME e EPP (LC 123/2006,
    # art. 18, §§ 20 e 20-A; Res. CGSN 140/2018, art. 35).
    DO_ESTADO = %w[isencao_icms reducao_icms].freeze
    DO_MUNICIPIO = %w[isencao_iss reducao_iss].freeze
    MERCADORIAS = (%w[st_icms monofasico exportacao] + DO_ESTADO).freeze
    SERVICOS = (%w[iss_retido exportacao] + DO_MUNICIPIO).freeze

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
      tipo("locacao", "Locação de bens móveis", 3, [], "LC 123/2006, art. 18, § 4º, V",
           tira: ["ISS"], motivo: "locação de bens móveis"),
      # Anexo III sem o ISS e com o ICMS do Anexo I (Res. CGSN 140/2018, art. 25, § 1º, IX).
      tipo("transporte", "Transporte intermunicipal ou interestadual, ou comunicação", 3, ["st_icms", *DO_ESTADO],
           "Res. CGSN 140/2018, art. 25, § 1º, IX",
           tira: ["ISS"], de_outro_anexo: { "ICMS" => 1 }, motivo: "transporte e comunicação pagam ICMS, e não ISS"),
      # Anexo II "deduzida a parcela correspondente ao ICMS e acrescida a parcela correspondente
      # ao ISS prevista no Anexo III" (art. 18, § 4º, VI; Res. CGSN 140/2018, art. 25, § 1º, VII).
      tipo("industria_iss", "Industrialização com IPI e ISS ao mesmo tempo", 2, SERVICOS,
           "LC 123/2006, art. 18, § 4º, VI; Res. CGSN 140/2018, art. 25, § 1º, VII",
           tira: ["ICMS"], de_outro_anexo: { "ISS" => 3 }, motivo: "a atividade com IPI e ISS paga ISS, e não ICMS")
    ].to_h { |tipo| [tipo.codigo, tipo] }.freeze

    # O que a pessoa informou, já conferido: tipo (Tipo), receita em centavos, os códigos dos
    # qualificadores e as reduções de ICMS e ISS ({ "ISS" => 2/5 } tira 40% do ISS).
    Atividade = Data.define(:tipo, :receita, :opcoes, :reducoes) do
      def initialize(tipo:, receita:, opcoes:, reducoes: {}) = super
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
      "ipi_mantido" => ["Produto com IPI mantido (Zona Franca de Manaus)", "IPI mantido", "%<res>s, art. 25, § 1º, II"],
      "isencao_icms" => ["Isenção do ICMS dada pelo estado", "isenção dada pelo estado",
                         "LC 123/2006, art. 18, §§ 20 e 20-A; %<res>s, art. 35, I"],
      "reducao_icms" => ["Redução do ICMS dada pelo estado", "redução dada pelo estado",
                         "LC 123/2006, art. 18, §§ 20 e 20-A; %<res>s, art. 35, II"],
      "isencao_iss" => ["Isenção do ISS dada pelo município", "isenção dada pelo município",
                        "LC 123/2006, art. 18, §§ 20 e 20-A; %<res>s, art. 35, I"],
      "reducao_iss" => ["Redução do ISS dada pelo município", "redução dada pelo município",
                        "LC 123/2006, art. 18, §§ 20 e 20-A; %<res>s, art. 35, II"]
    }.freeze

    # Qual imposto cada redução diminui.
    REDUCOES = { "reducao_icms" => "ICMS", "reducao_iss" => "ISS" }.freeze

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
      when "st_icms", "isencao_icms" then ["ICMS"]
      when "monofasico" then regras.tira_no_monofasico
      when "iss_retido", "isencao_iss" then ["ISS"]
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

    private_class_method :tipo, :nome_do_monofasico
  end
end
