# frozen_string_literal: true

module SimplesNacional
  # Fator R: decide entre o Anexo III e o Anexo V para as atividades que dependem da
  # folha de salários (LC 123/2006, art. 18, §§ 5º-J, 5º-K e 5º-M).
  #
  #   Fator R = folha de salários dos 12 meses ÷ receita bruta dos 12 meses (mercado interno
  #   mais exportação; Res. CGSN 140/2018, art. 26, II)
  #
  # Com 28% ou mais, a atividade vai para o Anexo III (§ 5º-J); abaixo de 28%, para o
  # Anexo V (§ 5º-M). A partir de 2027, no 1º e no 2º mês de atividade o Fator R é 28%
  # (art. 26, § 6º, na redação da Res. CGSN 190/2026).
  #
  # A folha de salários inclui os encargos: remunerações pagas a pessoas físicas pelo
  # trabalho, retiradas de pró-labore, contribuição patronal previdenciária e FGTS
  # efetivamente recolhidos (§ 24). Aluguéis e distribuição de lucros não entram (§ 26).
  # https://www.planalto.gov.br/ccivil_03/leis/lcp/lcp123.htm (conferido em 02/11/2026)
  module FatorR
    LIMITE = Rational(28, 100)

    # anexo: 3 ou 5. folha e rbt12: as da conta (nil no início de 2027). inicial: o Fator R
    # fixo de 28% do 1º e 2º mês.
    Resultado = Data.define(:anexo, :fator, :folha, :rbt12, :inicial)

    # Devolve o número do anexo (3 ou 5) e o Fator R (Rational). Valores em centavos.
    def self.anexo(rbt12, folha12)
      fator = Rational(folha12) / rbt12
      [fator >= LIMITE ? 3 : 5, fator]
    end

    # nil quando nenhuma atividade usa o Fator R.
    def self.calcular(dados)
      return unless dados.atividades.any? { |atividade| atividade.tipo.anexo == :fator_r }
      return Resultado.new(anexo: 3, fator: LIMITE, folha: nil, rbt12: nil, inicial: true) if dados.primeira_faixa

      rbt12 = rbt12(dados)
      folha = dados.folha.anualizada
      numero, fator = anexo(rbt12, folha)
      Resultado.new(anexo: numero, fator:, folha:, rbt12:, inicial: false)
    end

    # Mercado interno mais exportação. Sem receita antes do mês não há Fator R.
    def self.rbt12(dados)
      rbt12 = dados.interno.anualizada + dados.exportacao.anualizada
      return rbt12 if rbt12.positive?

      raise Entrada::EntradaInvalida, "Sem receita antes deste mês, não dá para calcular o Fator R (folha ÷ " \
                                      "receita): escolha os serviços do Anexo III ou do V."
    end

    private_class_method :rbt12
  end
end
