# frozen_string_literal: true

module SimplesNacional
  # A conta de uma receita do mês (uma atividade da segregação):
  #   1. o anexo vem do tipo de atividade (e do Fator R);
  #   2. a faixa e a alíquota efetiva vêm da RBT12 do mercado (interno ou exportação, que
  #      é considerada separada: Res. CGSN 140/2018, art. 23);
  #   3. a alíquota efetiva é dividida entre os tributos (Reparticao), com o sublimite e o
  #      limite do mercado interno;
  #   4. saem os tributos que a atividade não paga no DAS (Atividades.tira), o ICMS ou o ISS
  #      pago em valor fixo (ver ValoresFixos) e, com a opção do regime regular, a CBS e o IBS
  #      (Res. CGSN 140/2018, art. 22-A, redação da Res. 190/2026);
  #   5. a redução de ICMS ou de ISS dada pelo estado ou pelo município diminui o percentual
  #      desse imposto na mesma proporção (Res. CGSN 140/2018, art. 35, II);
  #   6. valor = receita × soma dos percentuais que sobraram, arredondado para o centavo.
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
      tirados = tirados(dados, atividade)
      conta = { numero:, atividade:, tabela:, faixa:, rbt12: mercado.anualizada, efetiva:, reparticao:, tirados: }
      com_valor(conta, no_das(dados, atividade, reparticao.except(*tirados)))
    end

    # O que a receita não paga no DAS: pelo tipo e pelos qualificadores, e o imposto pago em valor fixo.
    def self.tirados(dados, atividade) = (Atividades.tira(atividade, dados.regras) + dados.valores_fixos.keys).uniq

    # Sem a CBS e o IBS do regime regular e com a redução do estado ou do município:
    # { "ISS" => 2/5 } tira 40% do percentual do ISS.
    def self.no_das(dados, atividade, percentuais)
      percentuais = percentuais.except("CBS", "IBS") if dados.ibs_cbs_fora
      percentuais.to_h { |nome, percentual| [nome, percentual * (1 - atividade.reducoes.fetch(nome, 0))] }
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
    # tem o limite dela (ver LimiteDaExportacao) e já não tem ICMS nem ISS.
    def self.reparticao(dados, atividade, conta, mercado)
      situacao = atividade.exportacao? ? dados.situacao_exportacao : dados.situacao
      percentuais = Reparticao.percentuais(*conta, situacao)
      atividade.tipo.de_outro_anexo.reduce(percentuais) do |soma, (tributo, numero)|
        soma.merge(de_outro_anexo(dados, mercado, situacao, tributo, numero))
      end
    end

    # O imposto da mesma faixa em outro anexo: o ICMS do Anexo I no transporte e na
    # comunicação (Res. CGSN 140/2018, art. 25, § 1º, IX) e o ISS do Anexo III na atividade com
    # IPI e ISS (LC 123/2006, art. 18, § 4º, VI).
    def self.de_outro_anexo(dados, mercado, situacao, tributo, numero)
      outro = Regras.tabelas(dados.regras).fetch(numero)
      rbt12, faixa, efetiva = Calculo.faixa_e_aliquota(outro, mercado.anualizada)
      Reparticao.percentuais(outro, faixa, rbt12, efetiva, situacao).slice(tributo)
    end

    private_class_method :tabela, :tirados, :no_das, :com_valor, :reparticao, :de_outro_anexo
  end
end
