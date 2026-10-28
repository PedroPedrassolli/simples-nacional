# frozen_string_literal: true

require "test_helper"

describe SimplesNacional::Entrada do
  let(:entrada) { { periodo: "2026-03", anexo: 1, rbt12: 30_000_000, receita_mes: 2_500_000 } }

  def erro(**mudancas)
    assert_raises(SimplesNacional::Entrada::EntradaInvalida) { SimplesNacional.calcular(**entrada, **mudancas) }.message
  end

  it "pede o mês de apuração" do
    assert_match(/mês de apuração no formato AAAA-MM/, erro(periodo: nil))
  end

  it "recusa mês com bytes inválidos sem quebrar" do
    assert_match(/formato AAAA-MM/, erro(periodo: "\xFF\xFE"))
  end

  it "recusa mês que não existe" do
    assert_match(/formato AAAA-MM/, erro(periodo: "2026-13"))
  end

  it "recusa mês fora de 2026, porque as tabelas mudam em 2027" do
    assert_match(/só as regras de 2026.*LC 214\/2025, art\. 519/, erro(periodo: "2027-01"))
    assert_match(/só as regras de 2026/, erro(periodo: "2025-12"))
  end

  it "recusa início em formato errado" do
    assert_match(/início das atividades no formato AAAA-MM/, erro(inicio: "11/2025"))
  end

  it "recusa início depois do mês de apuração" do
    assert_match(/não pode ser depois do mês de apuração/, erro(inicio: "2026-04"))
  end

  it "pede a RBT12" do
    assert_equal "Informe a receita bruta dos 12 meses anteriores (RBT12).", erro(rbt12: nil)
  end

  it "pede a receita desde o início, com os meses no texto" do
    assert_equal "Informe a receita bruta desde o início das atividades (os 4 meses antes de março de 2026).",
                 erro(rbt12: nil, inicio: "2025-11")
    assert_match(/\(o mês antes de março de 2026\)/, erro(rbt12: nil, inicio: "2026-02"))
  end

  it "pede a folha do Fator R conforme o caso" do
    assert_match(/informe a folha de salários do mês\.\z/, erro(anexo: :fator_r, inicio: "2026-03"))
    assert_match(/informe a folha de salários desde o início das atividades/, erro(anexo: :fator_r, inicio: "2025-11"))
  end

  it "não calcula o Fator R sem receita anterior" do
    assert_match(/não dá para calcular o Fator R/, erro(anexo: :fator_r, rbt12: 0, folha12: 100))
  end
end
