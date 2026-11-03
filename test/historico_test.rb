# frozen_string_literal: true

require "test_helper"

# Mês a mês: a calculadora soma a janela da RBT12 (LC 123/2006, art. 18, § 1º; Res. CGSN 140/2018,
# art. 21, II, a; em 2027, os 12 meses antes do mês anterior, redação da Res. CGSN 190/2026), a
# receita do ano e a folha do Fator R. Valores fictícios.
describe SimplesNacional::Historico do
  # Um histórico de março de 2025 a fevereiro de 2026, com receita 40.000 + 1.000 por mês
  # (março de 2025 = 41.000 ... fevereiro de 2026 = 52.000) e folha de 12.000 por mês.
  let(:meses) do
    (1..12).to_h do |n|
      data = Date.new(2025, 2, 1).next_month(n)
      [data.strftime("%Y-%m"), { receita: (40_000 + (n * 1_000)) * 100, folha: 1_200_000 }]
    end
  end
  let(:entrada) { { periodo: "2026-03", anexo: :fator_r, receita_mes: 4_000_000, historico: meses } }

  subject { SimplesNacional.calcular(**entrada) }

  def erro = assert_raises(SimplesNacional::Entrada::EntradaInvalida) { subject }.message

  # RBT12 = 41.000 + ... + 52.000 = 558.000; receita de 2026 até fevereiro = 51.000 + 52.000 = 103.000;
  # folha = 144.000. Fator R = 144.000 ÷ 558.000 = 25,8% → Anexo V.
  it "soma a RBT12, a receita do ano e a folha" do
    dados = subject.dados
    assert_equal [55_800_000, 10_300_000, 14_400_000],
                 [dados.interno.informada, dados.receita_ano, dados.folha.informada]
    assert_equal 5, subject.anexo.numero
  end

  it "dá o mesmo DAS que os totais digitados à mão" do
    totais = SimplesNacional.calcular(periodo: "2026-03", anexo: :fator_r, receita_mes: 4_000_000,
                                      rbt12: 55_800_000, folha12: 14_400_000, receita_ano: 10_300_000)
    assert_equal totais.das, subject.das
  end

  it "explica a soma no passo a passo" do
    passo = subject.passos.find { |item| item.titulo == "Mês a mês" }
    assert_includes passo.texto, "RBT12 (soma de março de 2025 a fevereiro de 2026): R$ 558.000,00."
    assert_includes passo.texto, "Receita de 2026 até o mês anterior: R$ 103.000,00."
  end

  describe "em 2027" do
    # A RBT12 de março de 2027 vai de fevereiro de 2026 a janeiro de 2027 (pula fevereiro de 2027).
    let(:meses) do
      (0..12).to_h { |n| [Date.new(2026, 2, 1).next_month(n).strftime("%Y-%m"), { receita: 1_000_000 * (n + 1) }] }
    end
    let(:entrada) { { periodo: "2027-03", anexo: 3, receita_mes: 1_000_000, historico: meses } }

    it "pula o mês anterior na RBT12 e usa ele na receita do ano" do
      janela = subject.dados.historico
      assert_equal [Date.new(2026, 2, 1), Date.new(2027, 1, 1)], [janela.first, janela.last]
      # 10.000 + ... + 120.000 = 780.000; receita do ano = janeiro (120.000) + fevereiro (130.000).
      assert_equal [78_000_000, 25_000_000], [subject.dados.interno.informada, subject.dados.receita_ano]
      assert_includes subject.passos.find { |item| item.titulo == "Mês a mês" }.texto, "12 meses antes do mês anterior"
    end
  end

  describe "com início de atividade" do
    # Início em janeiro de 2026: a janela começa no início (janeiro e fevereiro).
    let(:meses) { { "2026-01" => { receita: 2_000_000 }, "2026-02" => { receita: 4_000_000 } } }
    let(:entrada) { { periodo: "2026-03", inicio: "2026-01", anexo: 1, receita_mes: 3_000_000, historico: meses } }

    it "soma só desde o início e anualiza" do
      # 60.000 ÷ 2 × 12 = 360.000.
      assert_equal [6_000_000, 36_000_000], [subject.dados.interno.informada, subject.dados.interno.anualizada]
    end
  end

  describe "com exportação" do
    let(:entrada) do
      historico = meses.transform_values { |mes| mes.merge(exportacao: 100_000) }
      { periodo: "2026-03", atividades: [{ tipo: "servicos_3", receita: 500_000, opcoes: ["exportacao"] }],
        historico: }
    end

    it "soma a exportação na mesma janela" do
      assert_equal 1_200_000, subject.dados.exportacao.informada
      assert_includes subject.passos.find { |item| item.titulo == "Mês a mês" }.texto, "Exportação na mesma janela"
    end
  end

  describe "sem um dos meses" do
    let(:entrada) { { periodo: "2026-03", anexo: 3, receita_mes: 100, historico: meses.except("2025-07") } }

    it("diz qual mês falta") { assert_match(/falta julho de 2025 \(use 0 se não houve receita\)/, erro) }
  end

  describe "com o mês a mês e os totais juntos" do
    let(:entrada) { { periodo: "2026-03", anexo: 3, receita_mes: 100, historico: meses, rbt12: 100 } }

    it("recusa") { assert_match(/Use o mês a mês ou os totais/, erro) }
  end

  describe "com um mês depois do mês de apuração" do
    let(:entrada) { { periodo: "2026-03", anexo: 3, receita_mes: 100, historico: { "2026-03" => { receita: 1 } } } }

    it("recusa") { assert_match(/"2026-03" não é um mês anterior ao de apuração/, erro) }
  end

  describe "com meses demais" do
    let(:entrada) do
      historico = (1..25).to_h { |n| [Date.new(2023, 1, 1).next_month(n).strftime("%Y-%m"), { receita: 1 }] }
      { periodo: "2026-03", anexo: 3, receita_mes: 100, historico: }
    end

    it("recusa") { assert_match(/no máximo 24 meses/, erro) }
  end

  describe "com valor negativo" do
    let(:entrada) { { periodo: "2026-03", anexo: 3, receita_mes: 100, historico: { "2026-02" => { receita: -1 } } } }

    it("recusa e diz o mês") { assert_match(/receita de fevereiro de 2026 não pode ser negativa/, erro) }
  end

  describe "que não é um mapa" do
    let(:entrada) { { periodo: "2026-03", anexo: 3, receita_mes: 100, historico: [1, 2] } }

    it("recusa") { assert_match(/precisa ser uma lista de meses/, erro) }
  end
end
