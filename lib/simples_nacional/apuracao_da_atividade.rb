# frozen_string_literal: true

module SimplesNacional
  # A conta de uma receita do mês (uma atividade da segregação):
  #   1. o anexo vem do tipo de atividade (e do Fator R);
  #   2. a faixa e a alíquota efetiva vêm da RBT12 do mercado (interno ou exportação, que
  #      é considerada separada: Res. CGSN 140/2018, art. 23);
  #   3. a alíquota efetiva é dividida entre os tributos (Reparticao), com o sublimite e o
  #      limite do mercado interno;
  #   4. saem os tributos que a atividade não paga no DAS (Atividades.tira) e, com a opção
  #      do regime regular, a CBS e o IBS (Res. CGSN 140/2018, art. 22-A, redação da Res. 190/2026);
  #   5. valor = receita × soma dos percentuais que sobraram, arredondado para o centavo.
  module ApuracaoDaAtividade
    # numero: 1, 2... (ordem informada). rbt12: a do mercado, como a conta usou (0 vira
    # R$ 1,00 só para a alíquota). reparticao: a divisão antes de tirar o que a atividade não
    # paga no DAS; percentuais: os que entram no DAS. tirados: os que o tipo e os qualificadores
    # tiram. total: a soma dos percentuais. valor: em centavos.
    Apurada = Data.define(:numero, :atividade, :tabela, :faixa, :rbt12, :efetiva, :reparticao, :percentuais,
                          :tirados, :total, :valor, :tributos)

    def self.calcular(dados, atividade, numero, fator_r)
      tabela = tabela(dados, atividade, fator_r)
      mercado = atividade.exportacao? ? dados.exportacao : dados.interno
      rbt12, faixa, efetiva = Calculo.faixa_e_aliquota(tabela, mercado.anualizada)
      reparticao = reparticao(dados, atividade, [tabela, faixa, rbt12, efetiva], mercado)
      tirados = Atividades.tira(atividade, dados.regras)
      conta = { numero:, atividade:, tabela:, faixa:, rbt12: mercado.anualizada, efetiva:, reparticao:, tirados: }
      com_valor(conta, reparticao.except(*tirados, *(dados.ibs_cbs_fora ? %w[CBS IBS] : [])))
    end

    def self.tabela(dados, atividade, fator_r)
      Regras.tabelas(dados.regras).fetch(Atividades.anexo(atividade, dados.regras, fator_r&.anexo))
    end

    def self.com_valor(conta, percentuais)
      receita = conta[:atividade].receita
      total = percentuais.values.sum
      Apurada.new(**conta, percentuais:, total:, valor: (receita * total).round(half: :up),
                           tributos: Calculo.tributos(receita, percentuais))
    end

    # A divisão da alíquota efetiva antes de tirar o que a atividade não paga. A exportação
    # não segue o sublimite do mercado interno (e já não tem ICMS nem ISS).
    def self.reparticao(dados, atividade, conta, mercado)
      situacao = atividade.exportacao? ? Sublimite::NO_DAS : dados.situacao
      percentuais = Reparticao.percentuais(*conta, situacao)
      return percentuais unless atividade.tipo.icms_do_anexo_i

      percentuais.merge(icms_do_anexo_i(dados, mercado, situacao))
    end

    # Transporte e comunicação: o ICMS da mesma faixa no Anexo I (Res. CGSN 140/2018, art. 25, § 1º, IX).
    def self.icms_do_anexo_i(dados, mercado, situacao)
      anexo_i = Regras.tabelas(dados.regras).fetch(1)
      rbt12, faixa, efetiva = Calculo.faixa_e_aliquota(anexo_i, mercado.anualizada)
      Reparticao.percentuais(anexo_i, faixa, rbt12, efetiva, situacao).slice("ICMS")
    end

    private_class_method :tabela, :com_valor, :reparticao, :icms_do_anexo_i
  end
end
