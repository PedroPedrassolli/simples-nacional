# frozen_string_literal: true

require "yaml"

module SimplesNacional
  # Sublimite do ICMS e do ISS: acima dele, esses dois impostos deixam de ser pagos no DAS.
  #
  # - Passou do sublimite no ano anterior: o ICMS/ISS do ano todo fica fora do DAS (LC
  #   123/2006, art. 20, §§ 1º e 1º-A; Res. CGSN 140/2018, art. 12, §§ 1º e 5º).
  # - Passou no ano: a parte da receita acima do sublimite paga o ICMS/ISS com um
  #   percentual maior (Res. CGSN 140/2018, art. 24, I) até os efeitos do impedimento, que
  #   começam no mês seguinte (excesso de mais de 20%) ou no ano seguinte (até 20%) (art. 12, § 1º).
  # - No ano de início de atividade, o sublimite é proporcional: R$ 300.000,00 por mês, do
  #   início até dezembro; com excesso de mais de 20%, o impedimento volta ao início (art. 12,
  #   §§ 2º a 4º).
  # - A receita do ano acima do limite de R$ 4.800.000,00 (proporcional no ano de início) tira a
  #   empresa do Simples (LC 123/2006, art. 3º, §§ 9º, 9º-A e 10): a calculadora não cobre.
  # https://normas.receita.fazenda.gov.br/sijut2consulta/link.action?idAto=92278 (conferido em 27/10/2026)
  module Sublimite
    ARQUIVO = File.expand_path("../../data/sublimite.yml", __dir__)

    # A fórmula do percentual maior usa a 5ª faixa com R$ 3.600.000,00 (art. 24, I, b, 2).
    # Com sublimite de R$ 1.800.000,00 seria a 4ª faixa (b, 1), mas nenhum estado o adotou
    # em 2025 e 2026: o arquivo com outro valor é recusado em vez de dar uma conta errada.
    VALOR = 360_000_000

    # Excesso de mais de 20% antecipa os efeitos (art. 12, § 1º, I, e § 4º, I).
    TOLERANCIA = Rational(6, 5)

    # tipo: :no_das, :majorado (parte da receita do mês com o percentual maior) ou :fora.
    # fracao: a parte da receita do mês com o percentual maior (0 a 1).
    # sublimite: o do ano (proporcional no ano de início). receita_ano: a receita do ano
    # antes do mês, ou nil quando não foi preciso saber. motivo: o caso, para o passo.
    Situacao = Data.define(:tipo, :fracao, :sublimite, :receita_ano, :motivo)

    # Quando não há sublimite a conferir (o caso comum).
    NO_DAS = Situacao.new(tipo: :no_das, fracao: 0, sublimite: VALOR, receita_ano: nil, motivo: :abaixo)

    def self.situacao(dados)
      ano = dados.periodo.year
      return fora(dados, :ano_anterior) if passou_no_ano_anterior?(dados, ano - 1)

      sublimite = proporcional(valor(ano), ano, dados.inicio)
      receita_ano = receita_do_ano(dados, sublimite)
      return NO_DAS.with(sublimite:) if receita_ano.nil?

      conferir_limite(receita_ano + dados.receita_mes, ano, dados.inicio)
      no_ano(dados, sublimite, receita_ano)
    end

    # Com a receita do ano conhecida: dentro do sublimite, acima dele ou já fora do DAS.
    def self.no_ano(dados, sublimite, receita_ano)
      total = receita_ano + dados.receita_mes
      base = NO_DAS.with(sublimite:, receita_ano:)
      return base.with(tipo: :fora, motivo: :inicio) if inicio_no_ano?(dados) && total > sublimite * TOLERANCIA
      return base.with(tipo: :fora, motivo: :excesso) if receita_ano > sublimite * TOLERANCIA
      return base if total <= sublimite

      fracao = Rational(total - [receita_ano, sublimite].max, dados.receita_mes)
      base.with(tipo: :majorado, fracao:, motivo: total > sublimite * TOLERANCIA ? :mais_de_20 : :ate_20)
    end

    # Sublimite ou limite no ano de início: valor ÷ 12 × meses do início até dezembro,
    # contando o mês do início inteiro (art. 12, § 2º; art. 24, § 1º).
    def self.proporcional(valor, ano, inicio)
      return valor unless inicio&.year == ano

      valor * (13 - inicio.month) / 12
    end

    def self.inicio_no_ano?(dados) = dados.inicio&.year == dados.periodo.year

    # A receita do ano antes do mês de apuração. Quem começou no ano já informou (é a receita
    # desde o início); em janeiro é zero. Nos outros casos só é pedida quando pode fazer
    # diferença: a RBT12 inclui esses meses, então RBT12 + receita do mês é o máximo possível.
    def self.receita_do_ano(dados, sublimite)
      return dados.rbt12_informada || 0 if inicio_no_ano?(dados)
      return 0 if dados.periodo.month == 1
      return conferida(dados) if dados.receita_ano
      return if dados.rbt12_informada + dados.receita_mes <= sublimite

      raise Entrada::EntradaInvalida, "Informe a receita bruta de #{dados.periodo.year} até o mês anterior: com " \
                                      "esses valores, a receita do ano pode passar do sublimite de " \
                                      "#{Formato.reais(sublimite)} do ICMS e do ISS."
    end

    def self.conferida(dados)
      return dados.receita_ano if dados.receita_ano <= dados.rbt12_informada

      raise Entrada::EntradaInvalida, "A receita de #{dados.periodo.year} até o mês anterior não pode ser maior " \
                                      "que a receita dos meses anteriores (RBT12), que inclui esses meses."
    end

    # Ano anterior: acima do limite, a empresa saiu do Simples; acima do sublimite, o
    # ICMS/ISS do ano fica fora do DAS. Sem a receita informada, considera que não passou.
    def self.passou_no_ano_anterior?(dados, ano)
      receita = dados.receita_ano_anterior
      return false if receita.nil? || dados.inicio&.year.to_i > ano

      conferir_limite(receita, ano, dados.inicio)
      receita > proporcional(valor(ano), ano, dados.inicio)
    end

    def self.conferir_limite(receita, ano, inicio)
      limite = proporcional(Entrada::TETO, ano, inicio)
      return if receita <= limite

      raise Entrada::EntradaInvalida, "A receita de #{ano} passa de #{Formato.reais(limite)}, o limite do Simples " \
                                      "Nacional#{' no ano de início' if inicio&.year == ano}: a empresa sai do " \
                                      "regime (LC 123/2006, art. 3º, §§ 9º, 9º-A e 10), e a calculadora não cobre " \
                                      "esse caso."
    end

    def self.fora(dados, motivo)
      NO_DAS.with(tipo: :fora, sublimite: valor(dados.periodo.year - 1), motivo:)
    end

    # { 2025 => { valor:, ato:, fonte: } } do data/sublimite.yml, lido uma vez só.
    def self.anos
      @anos ||= YAML.safe_load_file(ARQUIVO)["anos"].transform_values do |ano|
        valor = (Rational(ano["valor"]) * 100).to_i
        raise "data/sublimite.yml: só o sublimite de R$ 3.600.000,00 tem a fórmula" unless valor == VALOR

        { valor:, ato: ano["ato"], fonte: ano["fonte"] }
      end
    end

    def self.valor(ano) = anos.fetch(ano)[:valor]

    private_class_method :no_ano, :receita_do_ano, :conferida, :passou_no_ano_anterior?, :conferir_limite, :fora
  end
end
