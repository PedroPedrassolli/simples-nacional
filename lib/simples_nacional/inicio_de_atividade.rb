# frozen_string_literal: true

module SimplesNacional
  # Empresa com menos de 12 meses de atividade antes do mês de apuração. A lei manda
  # proporcionalizar a receita (LC 123/2006, art. 18, § 2º), e a Resolução CGSN 140/2018
  # diz como (art. 22, §§ 2º a 4º):
  #   - no 1º mês de atividade, RBT12 = receita do próprio mês × 12;
  #   - do 2º ao 12º mês, RBT12 = média da receita dos meses anteriores × 12;
  #   - a partir do 13º mês, a RBT12 normal (12 meses anteriores).
  # A folha de salários do Fator R segue a mesma regra (art. 26, § 4º).
  # https://normas.receita.fazenda.gov.br/sijut2consulta/link.action?idAto=92278 (conferido em 27/10/2026)
  module InicioDeAtividade
    # Meses de atividade antes do mês de apuração (0 = começou no próprio mês), ou nil
    # quando já são 12 ou mais e vale a regra normal.
    def self.meses(meses) = meses < 12 ? meses : nil

    # 1º mês: valor do mês × 12. Depois: (soma dos meses anteriores ÷ número de meses) × 12.
    # Rational: a média pode ter fração de centavo, e a conta usa o valor exato.
    def self.anualizar(valor, meses) = meses.zero? ? valor * 12 : Rational(valor * 12, meses)

    # Como pedir a receita anterior, conforme o caso (o texto vai nas mensagens de erro).
    def self.nome_da_receita(meses, periodo)
      return "a receita bruta dos 12 meses anteriores (RBT12)" if meses.nil?

      "a receita bruta desde o início das atividades (#{antes(meses, periodo)})"
    end

    def self.nome_da_folha(meses, periodo)
      return "a folha de salários dos 12 meses anteriores" if meses.nil?
      return "a folha de salários do mês" if meses.zero?

      "a folha de salários desde o início das atividades (#{antes(meses, periodo)})"
    end

    # "o mês antes de março de 2026" ou "os 4 meses antes de março de 2026"
    def self.antes(meses, periodo)
      quantos = meses == 1 ? "o mês" : "os #{meses} meses"
      "#{quantos} antes de #{Formato.mes(periodo)}"
    end

    private_class_method :antes
  end
end
