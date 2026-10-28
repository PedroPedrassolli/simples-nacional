# frozen_string_literal: true

require "test_helper"

# Empresa com menos de 12 meses de atividade (LC 123/2006, art. 18, § 2º; Res. CGSN
# 140/2018, art. 22, §§ 2º a 4º, e art. 26, § 4º). Valores fictícios, contas feitas à mão.
describe SimplesNacional::InicioDeAtividade do
  # No 1º mês de atividade (março de 2026). Os outros exemplos mudam a partir daqui.
  let(:primeiro_mes) { { periodo: "2026-03", anexo: 1, receita_mes: 2_000_000, inicio: "2026-03" } }
  let(:entrada) { primeiro_mes }

  subject { SimplesNacional.calcular(**entrada) }

  describe "no 1º mês de atividade" do
    # RBT12 = 20.000 × 12 = 240.000 → Anexo I, 2ª faixa: (240.000 × 7,3% − 5.940) ÷ 240.000 = 4,825%.
    # 20.000 × 4,825% = 965,00.
    it "usa a receita do mês × 12, sem pedir a receita anterior" do
      assert_equal [24_000_000, 96_500], [subject.rbt12, subject.das]
    end

    it "explica a conta no primeiro passo, com a base legal" do
      passo = subject.passos.first
      assert_equal "Início de atividade", passo.titulo
      assert_includes passo.texto, "A empresa começou em março de 2026, o próprio mês de apuração."
      assert_includes passo.texto, "A RBT12 é a receita do mês × 12: R$ 20.000,00 × 12 = R$ 240.000,00."
      assert_equal "LC 123/2006, art. 18, § 2º; Res. CGSN 140/2018, art. 22, § 2º", passo.fonte
    end

    describe "com o Fator R" do
      # Folha = 5.000 × 12 = 60.000; 60.000 ÷ 240.000 = 25% → Anexo V, 2ª faixa:
      # (240.000 × 18% − 4.500) ÷ 240.000 = 16,125%; 20.000 × 16,125% = 3.225,00.
      let(:entrada) { primeiro_mes.merge(anexo: :fator_r, folha12: 500_000) }

      it "anualiza a folha do mês do mesmo jeito" do
        assert_equal [5, Rational(1, 4), 322_500], [subject.anexo.numero, subject.fator_r, subject.das]
        assert_includes subject.passos.first.texto, "a folha do mês × 12: R$ 5.000,00 × 12 = R$ 60.000,00"
        assert_includes subject.passos.first.fonte, "art. 26, § 4º"
      end
    end
  end

  describe "com 4 meses de atividade antes do mês de apuração" do
    # Novembro e dezembro de 2025, janeiro e fevereiro de 2026: R$ 100.000,00 no total.
    # RBT12 = 100.000 ÷ 4 × 12 = 300.000 → Anexo I, 2ª faixa: (300.000 × 7,3% − 5.940) ÷ 300.000 = 5,32%.
    # 30.000 × 5,32% = 1.596,00.
    let(:quatro_meses) do
      { periodo: "2026-03", anexo: 1, inicio: "2025-11", rbt12: 10_000_000, receita_mes: 3_000_000 }
    end
    let(:entrada) { quatro_meses }

    it "usa a média dos meses anteriores × 12" do
      assert_equal [30_000_000, 159_600], [subject.rbt12, subject.das]
      assert_includes subject.passos.first.texto,
                      "4 meses de atividade antes de março de 2026. A RBT12 é a média dos meses anteriores × 12: " \
                      "R$ 100.000,00 ÷ 4 × 12 = R$ 300.000,00."
      assert_includes subject.passos.first.fonte, "art. 22, §§ 3º e 4º"
    end

    describe "com o Fator R" do
      # Folha de R$ 30.000,00 nos 4 meses: 30.000 ÷ 100.000 = 30% → Anexo III, 2ª faixa:
      # (300.000 × 11,2% − 9.360) ÷ 300.000 = 8,08%; 30.000 × 8,08% = 2.424,00.
      let(:entrada) { quatro_meses.merge(anexo: :fator_r, folha12: 3_000_000) }

      it "usa a folha anualizada" do
        assert_equal [3, Rational(3, 10), 242_400], [subject.anexo.numero, subject.fator_r, subject.das]
      end
    end
  end

  describe "com 1 mês de atividade antes" do
    let(:entrada) { { periodo: "2026-03", anexo: 1, inicio: "2026-02", rbt12: 1_000_000, receita_mes: 1_000_000 } }

    it "escreve no singular" do
      assert_includes subject.passos.first.texto, "fevereiro de 2026: 1 mês de atividade antes de março de 2026"
    end
  end

  describe "com média que não fecha em centavos" do
    # 7 meses (agosto de 2025 a fevereiro de 2026): 100.000 ÷ 7 × 12 = 171.428,571... → 1ª faixa.
    let(:entrada) { { periodo: "2026-03", anexo: 1, inicio: "2025-08", rbt12: 10_000_000, receita_mes: 1_000_000 } }

    it "usa o valor exato e mostra arredondado" do
      assert_equal Rational(10_000_000 * 12, 7), subject.rbt12
      assert_includes subject.passos.first.texto, "R$ 100.000,00 ÷ 7 × 12 = R$ 171.428,57."
      assert_equal 1, subject.faixa.numero
    end
  end

  describe "com 12 meses ou mais de atividade" do
    let(:entrada) { { periodo: "2026-03", anexo: 1, inicio: "2025-03", rbt12: 30_000_000, receita_mes: 2_500_000 } }

    it "usa a RBT12 normal, sem passo de início" do
      assert_equal [30_000_000, 133_000], [subject.rbt12, subject.das]
      assert_equal "Anexo", subject.passos.first.titulo
    end
  end

  describe "com a RBT12 anualizada acima de R$ 4.800.000,00" do
    # 1º mês com R$ 500.000,00: RBT12 = 6.000.000 → última faixa (Res. CGSN 140/2018, art. 22, § 5º).
    # Federais: (6.000.000 × 19% − 378.000) ÷ 6.000.000 = 12,7%; ICMS pela 5ª faixa:
    # (6.000.000 × 14,3% − 87.300) ÷ 6.000.000 × 33,5% = 4,303075%. 500.000 × 17,003075% = 85.015,375.
    let(:entrada) { primeiro_mes.merge(receita_mes: 50_000_000) }

    it "usa a 6ª faixa e avisa no passo" do
      assert_equal [6, 8_501_538], [subject.faixa.numero, subject.das]
      assert_includes subject.passos[2].texto, "acima do limite de R$ 4.800.000,00: a conta usa a última faixa"
    end
  end
end
