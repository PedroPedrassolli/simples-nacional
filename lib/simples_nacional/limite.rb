# frozen_string_literal: true

module SimplesNacional
  # Limite de receita do Simples: R$ 4.800.000,00 no ano (LC 123/2006, art. 3º, II), ou
  # R$ 400.000,00 por mês do início até dezembro no ano de início (§ 2º).
  #
  # - Passou do limite: a empresa é excluída a partir do mês seguinte, ou só no ano seguinte se o
  #   excesso for de até 20% (art. 3º, §§ 9º e 9º-A). No ano de início, com mais de 20%, a
  #   exclusão volta ao início das atividades (§§ 10 e 12).
  # - Até a exclusão, em 2026, a parte da receita do mês acima do limite paga os tributos
  #   federais pela alíquota efetiva da 6ª faixa calculada com R$ 4.800.000,00 (Res. CGSN
  #   140/2018, art. 24, II, e §§ 4º e 7º; LC 123/2006, art. 18, §§ 16 e 16-A). A partir de
  #   2027, ela é tributada junto com o resto (art. 24 na redação da Res. CGSN 190/2026).
  # - A calculadora recusa só quando a empresa já está fora do Simples no mês de apuração.
  # https://www.planalto.gov.br/ccivil_03/leis/lcp/lcp123.htm (conferido em 02/11/2026)
  module Limite
    def self.aplicar(dados, base)
      total = base.receita_ano + dados.interno.do_mes
      conferir_no_ano(dados, base, total)
      return base if total <= base.limite

      exclusao = total > base.limite * Sublimite::TOLERANCIA ? :mes_seguinte : :ano_seguinte
      base.with(exclusao:, fracao_limite: fracao(dados, base, total))
    end

    # Parte da receita interna do mês acima do limite (só a de 2026 tem percentual próprio).
    def self.fracao(dados, base, total)
      mes = dados.interno.do_mes
      return 0 unless dados.regras.majora_excesso && mes.positive?

      Rational(total - [base.receita_ano, base.limite].max, mes)
    end

    # Recusa quando a empresa já está fora do Simples no mês de apuração.
    def self.conferir_no_ano(dados, base, total)
      tolerancia = base.limite * Sublimite::TOLERANCIA
      inicio = Sublimite.inicio_no_ano?(dados)
      return unless inicio ? total > tolerancia : base.receita_ano > tolerancia

      raise Entrada::EntradaInvalida, inicio ? fora_desde_o_inicio(tolerancia) : fora_no_ano(dados, tolerancia)
    end

    def self.fora_desde_o_inicio(tolerancia)
      "A receita desde o início das atividades, com este mês, passa de #{Formato.reais(tolerancia)} (o limite " \
        "proporcional do ano de início mais 20%): a empresa é excluída do Simples desde o início (LC 123/2006, " \
        "art. 3º, §§ 10 e 12), e a calculadora não cobre esse caso."
    end

    def self.fora_no_ano(dados, tolerancia)
      "A receita de #{dados.periodo.year} até o mês anterior passa de #{Formato.reais(tolerancia)} (o limite mais " \
        "20%): a empresa saiu do Simples no mês seguinte ao excesso (LC 123/2006, art. 3º, §§ 9º e 9º-A), e a " \
        "calculadora não cobre esse caso."
    end

    # Acima do limite no ano anterior, a empresa já está fora do Simples neste ano.
    def self.conferir_ano_anterior(receita, ano, inicio)
      limite = Sublimite.proporcional(Entrada::LIMITE, ano, inicio)
      return if receita <= limite

      raise Entrada::EntradaInvalida, "A receita de #{ano} passa de #{Formato.reais(limite)}, o limite do Simples " \
                                      "Nacional#{' no ano de início' if inicio&.year == ano}: a empresa sai do " \
                                      "regime (LC 123/2006, art. 3º, §§ 9º, 9º-A e 10), e a calculadora não cobre " \
                                      "esse caso."
    end

    private_class_method :fracao, :conferir_no_ano, :fora_desde_o_inicio, :fora_no_ano
  end

  # A receita do ano antes do mês de apuração, que decide o sublimite e o limite.
  module ReceitaDoAno
    # nil quando não precisa saber: o máximo possível não chega ao sublimite (ou ao limite,
    # se o ICMS/ISS já está fora pelo ano anterior). Levanta EntradaInvalida se precisar e faltar.
    def self.calcular(dados, base)
      return no_inicio(dados) if Sublimite.inicio_no_ano?(dados)
      return 0 if dados.periodo.month == 1
      return conferida(dados) if dados.receita_ano

      maximo = maximo(dados)
      return if maximo && maximo + dados.interno.do_mes <= teto(base)

      raise Entrada::EntradaInvalida, pedido(dados, base, maximo)
    end

    # A parte do ano passado dentro da RBT12 não pode ser maior que a receita do ano passado inteiro.
    def self.conferir_ano_anterior(dados, receita_ano)
      anterior = dados.receita_ano_anterior
      return if anterior.nil? || dados.interno.informada.nil? || Sublimite.inicio_no_ano?(dados)

      parte = parte_do_ano_anterior(dados, receita_ano)
      return if parte.nil? || anterior >= parte

      raise Entrada::EntradaInvalida, "A receita de #{dados.periodo.year - 1} não pode ser menor que a parte " \
                                      "dela dentro da RBT12 (#{Formato.reais(parte)})."
    end

    # RBT12 menos os meses deste ano que estão nela. De 2027 em diante, a RBT12 não tem o mês
    # anterior; em janeiro ela ainda pega um mês de dois anos atrás (então não dá para conferir).
    def self.parte_do_ano_anterior(dados, receita_ano)
      informada = dados.interno.informada
      return informada - receita_ano unless dados.regras.rbt12_sem_o_mes_anterior
      return if dados.periodo.month == 1 || dados.receita_mes_anterior.nil?

      informada - (receita_ano - dados.receita_mes_anterior)
    end

    # No ano de início, a receita do ano é a desde o início. Em 2026 é a informada; de 2027
    # em diante, a informada vai até o mês retrasado, então soma o mês anterior.
    # (Em 2027, sem a receita do mês anterior, serve a receita do ano informada.)
    def self.no_inicio(dados)
      informada = dados.interno.informada || 0
      return informada unless dados.regras.rbt12_sem_o_mes_anterior
      return 0 if dados.meses.zero?
      return dados.receita_ano if dados.receita_ano && dados.receita_mes_anterior.nil?

      informada + mes_anterior(dados)
    end

    # O que importa saber: o sublimite, ou o limite se o ICMS/ISS já está fora pelo ano anterior.
    def self.teto(base) = base.local == :fora ? base.limite : base.sublimite

    def self.mes_anterior(dados)
      return dados.receita_mes_anterior if dados.receita_mes_anterior

      raise Entrada::EntradaInvalida, "Informe a receita do mês anterior (#{Formato.mes(dados.periodo.prev_month)})."
    end

    # O máximo que a receita do ano pode ter. Em 2026 a RBT12 inclui todos os meses do ano
    # antes do mês de apuração; de 2027 em diante, falta somar o mês anterior (nil se não veio).
    def self.maximo(dados)
      informada = dados.interno.informada
      return informada unless dados.regras.rbt12_sem_o_mes_anterior

      informada + dados.receita_mes_anterior if dados.receita_mes_anterior
    end

    def self.conferida(dados)
      maximo = maximo(dados)
      return dados.receita_ano if maximo.nil? || dados.receita_ano <= maximo

      meses = dados.regras.rbt12_sem_o_mes_anterior ? "RBT12 e mês anterior" : "RBT12"
      raise Entrada::EntradaInvalida, "A receita de #{dados.periodo.year} até o mês anterior não pode ser maior " \
                                      "que a receita dos meses anteriores (#{meses}), que inclui esses meses."
    end

    def self.pedido(dados, base, maximo)
      ano = dados.periodo.year
      if maximo.nil?
        return "Informe a receita do mês anterior (#{Formato.mes(dados.periodo.prev_month)}) ou a receita de " \
               "#{ano} até o mês anterior: sem elas, não dá para conferir o sublimite e o limite."
      end

      "Informe a receita bruta de #{ano} até o mês anterior: com esses valores, a receita do ano pode passar " \
        "#{qual_teto(base)}."
    end

    def self.qual_teto(base)
      return "do limite de #{Formato.reais(base.limite)} do Simples" if base.local == :fora

      "do sublimite de #{Formato.reais(base.sublimite)} do ICMS e do ISS"
    end

    private_class_method :parte_do_ano_anterior, :no_inicio, :teto, :mes_anterior, :maximo, :conferida, :pedido,
                         :qual_teto
  end
end
