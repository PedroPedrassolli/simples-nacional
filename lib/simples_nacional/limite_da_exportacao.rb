# frozen_string_literal: true

module SimplesNacional
  # O limite extra da exportação: além dos R$ 4.800.000,00 do mercado interno, a empresa pode
  # ter até R$ 4.800.000,00 de receita de exportação no ano (LC 123/2006, art. 3º, § 14; Res.
  # CGSN 140/2018, art. 2º, § 1º). As duas receitas contam separadas para a alíquota e para o
  # percentual maior acima do limite (art. 3º, § 15; Res. CGSN 140/2018, art. 24, § 8º).
  #
  # Acima do limite da exportação, valem as mesmas regras do mercado interno (ver Limite): em
  # 2026 a parte acima paga os tributos federais pela 6ª faixa com R$ 4.800.000,00, e a
  # exclusão vale no mês seguinte (excesso de mais de 20%) ou no ano seguinte. A exportação não
  # paga ICMS, ISS nem IBS, então o sublimite não muda a conta dela.
  # https://www.planalto.gov.br/ccivil_03/leis/lcp/lcp123.htm (conferido em 03/11/2026)
  module LimiteDaExportacao
    def self.situacao(dados)
      base = Sublimite::NO_DAS.with(limite: limite(dados))
      receita_ano = receita_ano(dados)
      return base if dados.exportacao.do_mes.zero? || receita_ano.nil?

      total = receita_ano + dados.exportacao.do_mes
      conferir(dados, base, receita_ano, total)
      return base.with(receita_ano:) if total <= base.limite

      acima(dados, base, receita_ano, total)
    end

    # R$ 4.800.000,00, ou proporcional aos meses no ano de início.
    def self.limite(dados) = Sublimite.proporcional(Entrada::LIMITE, dados.periodo.year, dados.inicio)

    # Passou do limite no mês: a exclusão e, em 2026, a parte do mês que paga o percentual maior.
    def self.acima(dados, base, receita_ano, total)
      exclusao = total > base.limite * Sublimite::TOLERANCIA ? :mes_seguinte : :ano_seguinte
      do_mes = dados.exportacao.do_mes
      fracao = dados.regras.majora_excesso ? Rational(total - [receita_ano, base.limite].max, do_mes) : 0
      base.with(receita_ano:, exclusao:, fracao_limite: fracao)
    end

    # A receita de exportação do ano antes do mês: a informada (ou a do mês a mês); no ano de
    # início em 2026, a desde o início (é a RBT12 informada); em janeiro, zero; senão nil.
    def self.receita_ano(dados)
      return dados.receita_ano_exportacao if dados.receita_ano_exportacao
      return 0 if dados.periodo.month == 1
      if Sublimite.inicio_no_ano?(dados) && !dados.regras.rbt12_sem_o_mes_anterior
        return dados.exportacao.informada.to_i
      end

      nil
    end

    # Já fora do Simples no mês: a receita de exportação passou do limite mais 20% antes dele.
    def self.conferir(dados, base, receita_ano, total)
      tolerancia = base.limite * Sublimite::TOLERANCIA
      inicio = Sublimite.inicio_no_ano?(dados)
      return unless inicio ? total > tolerancia : receita_ano > tolerancia

      raise Entrada::EntradaInvalida, "A receita de exportação de #{dados.periodo.year} passa de " \
                                      "#{Formato.reais(tolerancia)} (o limite extra da exportação mais 20%): a " \
                                      "empresa saiu do Simples (LC 123/2006, art. 3º, §§ 9º-A, 12 e 14), e a " \
                                      "calculadora não cobre esse caso."
    end

    # Aviso quando a receita de exportação do ano não veio e pode passar do limite.
    def self.aviso(dados)
      do_mes = dados.exportacao.do_mes
      return if do_mes.zero? || !receita_ano(dados).nil?

      limite = limite(dados)
      return if dados.exportacao.informada.to_i + do_mes <= limite

      "A RBT12 da exportação mais a exportação do mês passa de #{Formato.reais(limite)}: informe a receita de " \
        "exportação do ano até o mês anterior para conferir o limite extra da exportação (LC 123/2006, art. 3º, § 14)."
    end

    private_class_method :limite, :acima, :receita_ano, :conferir
  end
end
