# frozen_string_literal: true

module SimplesNacional
  # O que muda de um ano para o outro. A calculadora aceita meses de 2026 a 2028.
  #
  # 2026: Anexos I a V na redação da LC 155/2016 e a Resolução CGSN 140/2018.
  #
  # 2027 e 2028: Anexos da LC 214/2025 (art. 519; tabela "para os anos-calendário 2027 e
  # 2028") e a Res. CGSN 140/2018 na redação da Res. CGSN 190/2026, que vale a partir de
  # 1º/1/2027. As mudanças que entram na conta:
  #   - a RBT12 passa a ser dos 12 meses antes do mês anterior (art. 21, II, a);
  #   - no 1º e no 2º mês de atividade vale a 1ª faixa, e o Fator R é 28% (arts. 22, § 2º, e 26, § 6º);
  #   - acima do sublimite ou do limite, a receita é tributada junto com o resto, sem
  #     percentual maior (art. 24); o IBS sai do DAS junto com o ICMS e o ISS (art. 12);
  #   - a venda de produto industrializado vai para o Anexo I, menos a com IPI mantido, que fica
  #     no Anexo II (art. 25, § 1º, I e II);
  #   - a exportação e a tributação concentrada tiram a CBS e o IBS (art. 25, §§ 3º e 6º);
  #   - a empresa pode pagar o IBS e a CBS fora do DAS, no regime regular (arts. 22-A e 40-C).
  # Em 2029 as tabelas mudam de novo (a calculadora ainda não aceita).
  #
  # https://normas.receita.fazenda.gov.br/sijut2consulta/link.action?idAto=92278 (Res. 140, conferido em 02/11/2026)
  # https://normasinternet2.receita.fazenda.gov.br/#/consulta/externa/152832 (Res. 190, conferido em 02/11/2026)
  # https://www.planalto.gov.br/ccivil_03/leis/lcp/lcp214.htm (LC 214, conferido em 02/11/2026)
  module Regras
    # pasta: onde ficam as tabelas do ano (data/anexos/<pasta>). res: como citar a resolução.
    Ano = Data.define(:ano, :pasta, :res, :rbt12_sem_o_mes_anterior, :majora_excesso, :meses_na_primeira_faixa,
                      :tira_na_exportacao, :tira_no_monofasico, :anexo_da_industria, :ibs_cbs_por_fora)

    DE_2026 = Ano.new(
      ano: 2026, pasta: "2026", res: "Res. CGSN 140/2018",
      rbt12_sem_o_mes_anterior: false, majora_excesso: true, meses_na_primeira_faixa: 0,
      tira_na_exportacao: %w[Cofins PIS/Pasep IPI ICMS ISS], tira_no_monofasico: %w[Cofins PIS/Pasep],
      anexo_da_industria: 2, ibs_cbs_por_fora: false
    )

    DE_2027 = Ano.new(
      ano: 2027, pasta: "2027-2028", res: "Res. CGSN 140/2018 (redação da Res. CGSN 190/2026)",
      rbt12_sem_o_mes_anterior: true, majora_excesso: false, meses_na_primeira_faixa: 2,
      tira_na_exportacao: %w[CBS IBS IPI ICMS ISS], tira_no_monofasico: %w[CBS IBS],
      anexo_da_industria: 1, ibs_cbs_por_fora: true
    )

    ANOS = { 2026 => DE_2026, 2027 => DE_2027, 2028 => DE_2027.with(ano: 2028) }.freeze

    # As regras do ano, ou nil se a calculadora não cobre o ano.
    def self.do_ano(ano) = ANOS[ano]

    # As tabelas do ano: { 1 => Anexo, ... }. Lidas uma vez só por pasta.
    def self.tabelas(regras)
      @tabelas ||= {}
      @tabelas[regras.pasta] ||= Tabelas.todas(File.join(Tabelas::PASTA, regras.pasta))
    end
  end
end
