# frozen_string_literal: true

module SimplesNacional
  # Fator R: decide entre o Anexo III e o Anexo V para as atividades que dependem da
  # folha de salários (LC 123/2006, art. 18, §§ 5º-J, 5º-K e 5º-M).
  #
  #   Fator R = folha de salários dos 12 meses anteriores ÷ receita bruta dos 12 meses anteriores
  #
  # Com 28% ou mais, a atividade vai para o Anexo III (§ 5º-J); abaixo de 28%, para o
  # Anexo V (§ 5º-M).
  #
  # A folha de salários inclui os encargos: remunerações pagas a pessoas físicas pelo
  # trabalho, retiradas de pró-labore, contribuição patronal previdenciária e FGTS
  # efetivamente recolhidos (§ 24). Aluguéis e distribuição de lucros não entram (§ 26).
  # https://www.planalto.gov.br/ccivil_03/leis/lcp/lcp123.htm (conferido em 27/10/2026)
  module FatorR
    LIMITE = Rational(28, 100)

    # Devolve o número do anexo (3 ou 5) e o Fator R (Rational). Valores em centavos.
    def self.anexo(rbt12, folha12)
      fator = Rational(folha12, rbt12)
      [fator >= LIMITE ? 3 : 5, fator]
    end
  end
end
