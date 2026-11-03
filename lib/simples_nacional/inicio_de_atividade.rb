# frozen_string_literal: true

module SimplesNacional
  # Empresa em início de atividade. A lei manda proporcionalizar a receita (LC 123/2006,
  # art. 18, § 2º), e a Resolução CGSN 140/2018 diz como (art. 22, §§ 2º a 4º).
  #
  # Em 2026:
  #   - no 1º mês de atividade, RBT12 = receita do próprio mês × 12;
  #   - do 2º ao 12º mês, RBT12 = média da receita dos meses anteriores × 12;
  #   - a partir do 13º mês, a RBT12 normal (12 meses anteriores).
  # Em 2027 e 2028 (redação da Res. CGSN 190/2026):
  #   - no 1º e no 2º mês, as alíquotas da 1ª faixa;
  #   - do 3º ao 13º mês, média dos meses antes do mês anterior × 12;
  #   - a partir do 14º mês, a RBT12 normal.
  # A folha de salários do Fator R segue a mesma regra (art. 26, § 4º).
  # https://normas.receita.fazenda.gov.br/sijut2consulta/link.action?idAto=92278 (conferido em 02/11/2026)
  module InicioDeAtividade
    # Meses de atividade antes do mês de apuração (0 = começou no próprio mês), ou nil
    # quando já vale a regra normal (12 meses em 2026, 13 em 2027).
    def self.meses(meses, regras)
      limite = regras.rbt12_sem_o_mes_anterior ? 13 : 12
      meses < limite ? meses : nil
    end

    # 2027 em diante: o 1º e o 2º mês usam a 1ª faixa, sem RBT12.
    def self.primeira_faixa?(meses, regras) = !meses.nil? && meses < regras.meses_na_primeira_faixa

    # Quantos meses entram na média (0 = a conta usa o próprio mês × 12).
    def self.divisor(meses, regras) = regras.rbt12_sem_o_mes_anterior ? meses - 1 : meses

    # Valor informado → valor de 12 meses. Rational: a média pode ter fração de centavo, e a
    # conta usa o valor exato.
    def self.anualizar(valor, meses, regras)
      divisor = divisor(meses, regras)
      divisor.zero? ? valor * 12 : Rational(valor * 12, divisor)
    end

    # Como pedir a receita anterior, conforme o caso (o texto vai nas mensagens de erro).
    def self.nome_da_receita(meses, periodo, regras)
      return "a receita bruta dos 12 meses anteriores (RBT12)" if meses.nil? && !regras.rbt12_sem_o_mes_anterior
      return "a receita bruta dos 12 meses antes do mês anterior (RBT12)" if meses.nil?

      "a receita bruta desde o início das atividades (#{antes(meses, periodo, regras)})"
    end

    def self.nome_da_folha(meses, periodo, regras)
      return "a folha de salários dos 12 meses da RBT12" if meses.nil?
      return "a folha de salários do mês" if divisor(meses, regras).zero?

      "a folha de salários desde o início das atividades (#{antes(meses, periodo, regras)})"
    end

    # "o mês antes de março de 2026" ou "os 4 meses antes de março de 2026"; em 2027, os
    # meses antes do mês anterior.
    def self.antes(meses, periodo, regras)
      divisor = divisor(meses, regras)
      quantos = divisor == 1 ? "o mês" : "os #{divisor} meses"
      return "#{quantos} antes de #{Formato.mes(periodo)}" unless regras.rbt12_sem_o_mes_anterior

      "#{quantos} antes de #{Formato.mes(periodo.prev_month)}"
    end

    private_class_method :antes
  end
end
