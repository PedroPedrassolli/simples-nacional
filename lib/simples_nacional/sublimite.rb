# frozen_string_literal: true

require "yaml"

module SimplesNacional
  # Sublimite do ICMS e do ISS (e do IBS, a partir de 2027): acima dele, esses impostos deixam
  # de ser pagos no DAS. O limite de R$ 4.800.000,00 fica em Limite.
  #
  # - Passou do sublimite no ano anterior: o ICMS/ISS do ano todo fica fora do DAS (LC
  #   123/2006, art. 20, §§ 1º e 1º-A; Res. CGSN 140/2018, art. 12, §§ 1º e 5º).
  # - Passou no ano: os efeitos do impedimento começam no mês seguinte (excesso de mais de
  #   20%) ou no ano seguinte (até 20%) (art. 12, § 1º). Até lá, em 2026, a parte da receita
  #   acima do sublimite paga o ICMS/ISS pela alíquota efetiva da 5ª faixa no valor do
  #   sublimite (Res. CGSN 140/2018, art. 24, I; LC 123/2006, art. 18, §§ 17 e 17-A); a partir
  #   de 2027, ela é tributada junto com o resto, pela alíquota normal (art. 24 na redação da
  #   Res. CGSN 190/2026).
  # - No ano de início de atividade, o sublimite é proporcional: R$ 300.000,00 por mês, do
  #   início até dezembro; com excesso de mais de 20%, o impedimento volta ao início (art. 12,
  #   §§ 2º a 4º).
  # https://normas.receita.fazenda.gov.br/sijut2consulta/link.action?idAto=92278 (conferido em 02/11/2026)
  module Sublimite
    ARQUIVO = File.expand_path("../../data/sublimite.yml", __dir__)

    # A fórmula do percentual maior usa a 5ª faixa com R$ 3.600.000,00 (art. 24, I, b, 2).
    # Com sublimite de R$ 1.800.000,00 seria a 4ª faixa (b, 1), mas nenhum estado o adotou
    # de 2025 a 2026, e a partir de 2027 ele é R$ 3.600.000,00 em todo o país (art. 9º na
    # redação da Res. CGSN 190/2026): o arquivo com outro valor é recusado.
    VALOR = 360_000_000

    # Excesso de mais de 20% antecipa os efeitos (art. 12, § 1º, I, e § 4º, I; LC 123/2006, art. 3º, § 9º-A).
    TOLERANCIA = Rational(6, 5)

    # local: :no_das ou :fora (o ICMS, o ISS e o IBS do mês fora do DAS).
    # fracao_sublimite: parte da receita interna do mês entre o sublimite e o limite, com o
    # percentual maior (só em 2026). fracao_limite: parte acima do limite (ver Limite).
    # sublimite e limite: os do ano (proporcionais no ano de início). receita_ano: a receita
    # do ano antes do mês, ou nil quando não foi preciso saber. motivo: o caso, para o passo
    # (:abaixo, :ano_anterior, :excesso, :inicio, e, quando o mês passa do sublimite,
    # :pouco_acima, com excesso de até 20%, e :muito_acima, com mais de 20%).
    # exclusao: nil, :mes_seguinte ou :ano_seguinte, quando a receita passa do limite.
    Situacao = Data.define(:local, :fracao_sublimite, :fracao_limite, :sublimite, :limite, :receita_ano, :motivo,
                           :exclusao)

    # Quando não há sublimite a conferir (o caso comum).
    NO_DAS = Situacao.new(local: :no_das, fracao_sublimite: 0, fracao_limite: 0, sublimite: VALOR,
                          limite: Entrada::LIMITE, receita_ano: nil, motivo: :abaixo, exclusao: nil)

    def self.situacao(dados)
      base = do_ano(dados)
      receita_ano = ReceitaDoAno.calcular(dados, base)
      return base if receita_ano.nil?

      ReceitaDoAno.conferir_ano_anterior(dados, receita_ano)
      base = Limite.aplicar(dados, base.with(receita_ano:))
      base.motivo == :ano_anterior ? base : no_ano(dados, base)
    end

    # O sublimite e o limite do ano, e o ICMS/ISS fora do DAS pelo ano anterior.
    def self.do_ano(dados)
      ano = dados.periodo.year
      base = NO_DAS.with(sublimite: proporcional(valor(ano), ano, dados.inicio),
                         limite: proporcional(Entrada::LIMITE, ano, dados.inicio))
      passou_no_ano_anterior?(dados, ano - 1) ? base.with(local: :fora, motivo: :ano_anterior) : base
    end

    # Com a receita do ano conhecida: dentro do sublimite, acima dele ou já fora do DAS.
    def self.no_ano(dados, base)
      total = base.receita_ano + dados.interno.do_mes
      motivo = motivo_fora(dados, base, total)
      return base.with(local: :fora, motivo:) if motivo
      return base if total <= base.sublimite

      acima(dados, base.with(motivo: total > base.sublimite * TOLERANCIA ? :muito_acima : :pouco_acima), total)
    end

    # O mês passou do sublimite. Em 2026, a parte entre o sublimite e o limite usa o percentual maior.
    def self.acima(dados, base, total)
      mes = dados.interno.do_mes
      return base unless dados.regras.majora_excesso && mes.positive?

      parte = [total, base.limite].min - [base.receita_ano, base.sublimite].max
      base.with(fracao_sublimite: Rational([parte, 0].max, mes))
    end

    # Excesso de mais de 20%: no ano de início, conta a receita com este mês e o impedimento
    # volta ao início (art. 12, § 4º, I); nos outros anos, o ICMS/ISS sai a partir do mês
    # seguinte ao excesso, então conta a receita até o mês anterior (art. 12, § 1º, I).
    def self.motivo_fora(dados, base, total)
      tolerancia = base.sublimite * TOLERANCIA
      return :inicio if inicio_no_ano?(dados) && total > tolerancia

      :excesso if base.receita_ano > tolerancia
    end

    # Sublimite ou limite no ano de início: valor ÷ 12 × meses do início até dezembro,
    # contando o mês do início inteiro (art. 12, § 2º; art. 24, § 1º; LC 123/2006, art. 3º, § 2º).
    def self.proporcional(valor, ano, inicio)
      return valor unless inicio&.year == ano

      valor * (13 - inicio.month) / 12
    end

    def self.inicio_no_ano?(dados) = dados.inicio&.year == dados.periodo.year

    # Ano anterior: acima do limite, a empresa saiu do Simples; acima do sublimite, o
    # ICMS/ISS do ano fica fora do DAS. Sem a receita informada, considera que não passou.
    def self.passou_no_ano_anterior?(dados, ano)
      receita = dados.receita_ano_anterior
      return false if receita.nil? || dados.inicio&.year.to_i > ano

      Limite.conferir_ano_anterior(receita, ano, dados.inicio)
      receita > proporcional(valor(ano), ano, dados.inicio)
    end

    # { 2025 => { valor:, ato:, fonte: } } do data/sublimite.yml, lido uma vez só.
    def self.anos = @anos ||= ler(ARQUIVO)

    def self.ler(arquivo)
      YAML.safe_load_file(arquivo)["anos"].transform_values do |ano|
        valor = (Rational(ano["valor"]) * 100).to_i
        raise "#{File.basename(arquivo)}: só o sublimite de R$ 3.600.000,00 tem a fórmula" unless valor == VALOR

        { valor:, ato: ano["ato"], fonte: ano["fonte"] }
      end
    end

    def self.valor(ano) = anos.fetch(ano)[:valor]

    private_class_method :do_ano, :no_ano, :acima, :motivo_fora, :passou_no_ano_anterior?
  end
end
