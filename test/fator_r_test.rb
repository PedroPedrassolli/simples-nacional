# frozen_string_literal: true

require "test_helper"

# Valores fictícios. As contas esperadas foram feitas à mão a partir das tabelas dos
# Anexos III e V (data/anexos/) e da regra dos 28% (LC 123/2006, art. 18, §§ 5º-J e 5º-M).
describe SimplesNacional::FatorR do
  let(:folha12) { 15_000_000 }
  let(:entrada) { { periodo: "2026-03", rbt12: 50_000_000, receita_mes: 4_000_000, anexo: :fator_r, folha12: } }

  subject { SimplesNacional.calcular(**entrada) }

  def erro(**mudancas)
    assert_raises(SimplesNacional::Calculo::EntradaInvalida) { SimplesNacional.calcular(**entrada, **mudancas) }.message
  end

  describe "com Fator R de 30%" do
    # R$ 150.000 ÷ R$ 500.000 = 30% → Anexo III, 3ª faixa: alíquota efetiva de 9,972% e DAS de R$ 3.988,80.
    it "usa o Anexo III" do
      assert_equal [3, Rational(3, 10)], [subject.anexo.numero, subject.fator_r]
    end

    it "calcula o DAS pelo Anexo III" do
      assert_equal 398_880, subject.das
    end

    it "explica o Fator R no primeiro passo" do
      assert_equal "Fator R", subject.passos.first.titulo
      assert_includes subject.passos.first.texto, "R$ 150.000,00 ÷ R$ 500.000,00 = 30,00%. Como é 28% ou mais"
    end
  end

  describe "com Fator R de exatamente 28%" do
    let(:folha12) { 14_000_000 }

    it "usa o Anexo III (28% ou mais)" do
      assert_equal 3, subject.anexo.numero
    end
  end

  describe "com Fator R 1 centavo abaixo de 28%" do
    # R$ 139.999,99 ÷ R$ 500.000 = 27,999998% → Anexo V, 3ª faixa:
    # (500.000 × 19,5% − 9.900) ÷ 500.000 = 17,52%; 40.000 × 17,52% = R$ 7.008,00.
    let(:folha12) { 13_999_999 }

    it "usa o Anexo V" do
      assert_equal 5, subject.anexo.numero
    end

    it "calcula o DAS pelo Anexo V" do
      assert_equal 700_800, subject.das
    end

    it "não mostra 28,00% no passo, para não confundir" do
      assert_includes subject.passos.first.texto, "= 27,99%. Como é menor que 28%, a atividade vai para o Anexo V"
    end
  end

  describe "sem folha de salários (zero)" do
    let(:folha12) { 0 }

    it "usa o Anexo V" do
      assert_equal [5, 0], [subject.anexo.numero, subject.fator_r]
    end
  end

  describe "com o anexo informado" do
    let(:entrada) { { periodo: "2026-03", rbt12: 50_000_000, receita_mes: 4_000_000, anexo: 3, folha12: 0 } }

    it "não usa a folha nem o Fator R" do
      assert_equal [3, nil, "Anexo"], [subject.anexo.numero, subject.fator_r, subject.passos.first.titulo]
    end
  end

  describe "com entradas inválidas" do
    it "pede a folha quando ela falta" do
      assert_match(/informe a folha de salários/, erro(folha12: nil))
    end

    it "recusa folha negativa" do
      assert_match(/não pode ser negativa/, erro(folha12: -1))
    end

    it "recusa folha como texto" do
      assert_match(/número inteiro de centavos/, erro(folha12: "150000"))
    end
  end
end
