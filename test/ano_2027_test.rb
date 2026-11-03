# frozen_string_literal: true

require "test_helper"

# Regras de 2027 e 2028: Anexos da LC 214/2025 (art. 519; Anexo III com a correção da LC 227/2026) e a
# Res. CGSN 140/2018 na redação da Res. CGSN 190/2026. Valores fictícios, conferidos com uma
# implementação independente em Python.
describe "regras de 2027" do
  let(:entrada) { { periodo: "2027-01", rbt12: 50_000_000, anexo: 3, receita_mes: 4_000_000 } }

  subject { SimplesNacional.calcular(**entrada) }

  def erro = assert_raises(SimplesNacional::Entrada::EntradaInvalida) { subject }.message

  def receita(tipo, valor, *opcoes) = { tipo:, receita: valor, opcoes: }

  def passo(titulo) = subject.passos.find { |item| item.titulo.start_with?(titulo) }

  # A alíquota nominal das faixas 1 a 5 não mudou: 9,972% × 40.000 = 3.988,80, como em 2026.
  it "divide entre a CBS e o IBS em vez de Cofins e PIS/Pasep" do
    assert_equal 398_880, subject.das
    assert_equal %w[IRPJ CSLL CBS CPP ISS IBS], subject.tributos.map(&:nome)
    assert_includes passo("Anexo").fonte, "na redação da LC 214/2025"
  end

  describe "fora de janeiro, sem a receita do mês anterior" do
    let(:entrada) { { periodo: "2027-03", rbt12: 50_000_000, anexo: 3, receita_mes: 4_000_000 } }

    it("pede a receita do mês anterior ou a do ano") {
      assert_match(/Informe a receita do mês anterior \(fevereiro/, erro)
    }
  end

  describe "sem a RBT12" do
    let(:entrada) { { periodo: "2027-03", anexo: 3, receita_mes: 4_000_000 } }

    it("explica que a RBT12 é dos 12 meses antes do mês anterior") do
      assert_match(/12 meses antes do mês anterior \(RBT12\)/, erro)
    end
  end

  describe "com venda de produto industrializado" do
    let(:entrada) { { periodo: "2027-01", rbt12: 50_000_000, atividades: [receita("industria", 1_000_000)] } }

    # Vai para o Anexo I (Res. CGSN 140/2018, art. 25, § 1º, I): 6,728% × 10.000 = 672,80.
    it "usa o Anexo I" do
      assert_equal [1, 67_280], [subject.anexo.numero, subject.das]
      assert_includes passo("Anexo").texto,
                      "A partir de 2027, a venda de produto fabricado pela empresa vai para o Anexo I"
    end

    describe "com IPI mantido (Zona Franca)" do
      let(:entrada) do
        { periodo: "2027-01", rbt12: 50_000_000, atividades: [receita("industria", 1_000_000, "ipi_mantido")] }
      end

      # Anexo II, 3ª faixa: (500.000 × 10% − 13.860) ÷ 500.000 = 7,228%; × 10.000 = 722,80.
      it "fica no Anexo II" do
        assert_equal [2, 72_280], [subject.anexo.numero, subject.das]
      end
    end

    describe "pelo jeito antigo (anexo 2)" do
      let(:entrada) { { periodo: "2027-01", rbt12: 50_000_000, anexo: 2, receita_mes: 1_000_000 } }

      it("continua no Anexo II") { assert_equal 2, subject.anexo.numero }
    end
  end

  describe "com tributação concentrada" do
    let(:entrada) do
      { periodo: "2027-01", rbt12: 50_000_000, atividades: [receita("revenda", 3_000_000, "monofasico")] }
    end

    # CBS 15,33% + IBS 0,17% = 15,5%: 6,728% × 84,5% × 30.000 = 1.705,55.
    it "tira a CBS e o IBS" do
      assert_equal 170_555, subject.das
      assert_includes passo("O que").texto, "a CBS e o IBS (tributação concentrada (monofásica))"
    end
  end

  describe "com o IBS e a CBS no regime regular" do
    let(:entrada) do
      { periodo: "2027-01", rbt12: 50_000_000, ibs_cbs_fora: true, atividades: [receita("revenda", 3_000_000)] }
    end

    it "tira a CBS e o IBS do DAS (art. 22-A)" do
      assert_equal 170_555, subject.das
      assert_includes passo("O que").texto, "(pagos fora do DAS, no regime regular)"
    end

    describe "em 2026" do
      let(:entrada) { { periodo: "2026-01", rbt12: 50_000_000, anexo: 1, receita_mes: 100, ibs_cbs_fora: true } }

      it("recusa a opção, que só existe a partir de 2027") { assert_match(/só existe a partir de 2027/, erro) }
    end
  end

  describe "com o ISS acima do teto no Anexo IV" do
    let(:entrada) { { periodo: "2027-01", rbt12: 350_000_000, anexo: 4, receita_mes: 10_000_000 } }

    # 5ª faixa: 16,7491%; ISS 40% = 6,6997% > 5%. Os outros (federais e IBS) ficam com (16,7491% − 5%)
    # × os pesos da nota do anexo: IBS 0,40%.
    it "transfere a diferença também para o IBS" do
      assert_equal 1_674_914, subject.das
      efetiva = Rational((350_000_000 * 22 / 100) - 18_378_000, 350_000_000)
      iss, ibs = subject.atividades.first.percentuais.values_at("ISS", "IBS")
      assert_equal [Rational(5, 100), (efetiva - Rational(5, 100)) * Rational(4, 1000)], [iss, ibs]
      assert_includes passo("Divisão").texto, "os tributos federais e o IBS dividem o resto"
    end
  end

  describe "na 6ª faixa" do
    let(:entrada) { { periodo: "2027-01", rbt12: 400_000_000, anexo: 1, receita_mes: 40_000_000 } }

    # Federais: (4.000.000 × 18,9% − 378.000) ÷ 4.000.000 = 9,45%. ICMS e IBS pela 5ª faixa:
    # 12,1175% × (33,5% + 0,17%) (art. 21, IV). 400.000 × 13,53% = 54.119,85.
    it "calcula o ICMS e o IBS pela 5ª faixa" do
      assert_equal 5_411_985, subject.das
      assert_includes passo("Divisão").texto, "O ICMS e o IBS usam a alíquota efetiva da 5ª faixa"
    end
  end

  describe "no início de atividade" do
    describe "no 1º mês, com Fator R" do
      let(:entrada) { { periodo: "2027-03", inicio: "2027-03", atividades: [receita("fator_r", 2_000_000)] } }

      # 1ª faixa do Anexo III (Fator R de 28%, art. 26, § 6º): 6% × 20.000 = 1.200,00.
      it "usa a 1ª faixa e o Fator R de 28%" do
        assert_equal [3, 1, Rational(28, 100), 120_000],
                     [subject.anexo.numero, subject.faixa.numero, subject.fator_r, subject.das]
        assert_includes passo("Início").texto, "este é o 1º mês de atividade"
      end
    end

    describe "no 2º mês" do
      let(:entrada) do
        { periodo: "2027-04", inicio: "2027-03", receita_mes_anterior: 1_500_000, anexo: 1, receita_mes: 2_000_000 }
      end

      it("ainda usa a 1ª faixa") { assert_equal [1, 80_000], [subject.faixa.numero, subject.das] }
    end

    describe "no 3º mês, sem a receita do mês anterior" do
      let(:entrada) { { periodo: "2027-05", inicio: "2027-03", rbt12: 2_000_000, anexo: 1, receita_mes: 2_000_000 } }

      it("pede a receita do mês anterior") { assert_match(/Informe a receita do mês anterior \(abril de 2027\)/, erro) }
    end

    describe "no 5º mês" do
      # Março a junho de atividade antes de julho; a média usa os meses antes de junho (3):
      # 60.000 ÷ 3 × 12 = 240.000 → Anexo I, 2ª faixa: 4,825% × 20.000 = 965,00.
      let(:entrada) do
        { periodo: "2027-07", inicio: "2027-03", rbt12: 6_000_000, receita_mes_anterior: 2_000_000, anexo: 1,
          receita_mes: 2_000_000 }
      end

      it "anualiza os meses antes do mês anterior" do
        assert_equal [24_000_000, 96_500], [subject.rbt12, subject.das]
        assert_includes passo("Início").texto, "média dos meses antes do mês anterior × 12: R$ 60.000,00 ÷ 3 × 12"
      end
    end
  end

  describe "com o sublimite" do
    describe "passando neste mês" do
      # 3.400.000 + 400.000 = 3.800.000: acima de 3.600.000, até 20%. Sem percentual maior: 5ª faixa com a
      # RBT12 de 3.300.000, (3.300.000 × 14,3% − 87.300) ÷ 3.300.000 = 11,6545%; × 400.000 = 46.618,18.
      let(:entrada) do
        { periodo: "2027-10", rbt12: 330_000_000, receita_mes_anterior: 30_000_000, receita_ano: 340_000_000,
          anexo: 1, receita_mes: 40_000_000 }
      end

      it "tributa pela alíquota normal e avisa a saída no ano seguinte" do
        assert_equal [:no_das, :pouco_acima, 4_661_818], [subject.situacao.local, subject.situacao.motivo, subject.das]
        assert_includes SimplesNacional::Avisos.montar(subject), "A receita do ano passou do sublimite: o ICMS e " \
                                                                 "o IBS saem do DAS em 1º de janeiro de 2028."
      end
    end

    describe "passando em mais de 20% neste mês" do
      # 3.400.000 + 1.000.000 = 4.400.000 > 4.320.000: sai do DAS a partir do mês seguinte.
      let(:entrada) do
        { periodo: "2027-10", rbt12: 330_000_000, receita_mes_anterior: 30_000_000, receita_ano: 340_000_000,
          anexo: 1, receita_mes: 100_000_000 }
      end

      it "avisa a saída no mês seguinte" do
        assert_equal :muito_acima, subject.situacao.motivo
        assert_includes SimplesNacional::Avisos.montar(subject).first, "saem do DAS a partir do mês seguinte"
      end
    end

    describe "passado no ano anterior" do
      # Receita de 2026 acima do sublimite: o ICMS e o IBS ficam fora o ano todo (art. 12). 6ª faixa,
      # federais: (3.700.000 × 18,9% − 378.000) ÷ 3.700.000 = 8,6838%; × 300.000 = 26.051,35.
      let(:entrada) do
        { periodo: "2027-03", rbt12: 370_000_000, receita_mes_anterior: 30_000_000, receita_ano: 60_000_000,
          receita_ano_anterior: 370_000_000, anexo: 1, receita_mes: 30_000_000 }
      end

      it "deixa o ICMS e o IBS fora do DAS" do
        assert_equal [:fora, 2_605_135], [subject.situacao.local, subject.das]
        assert_match(/O ICMS e o IBS deste mês não entram no DAS/, SimplesNacional::Avisos.montar(subject).first)
      end
    end

    it "lê o sublimite de 2027 da Res. CGSN 190/2026" do
      assert_equal 360_000_000, SimplesNacional::Sublimite.valor(2027)
    end
  end
end
