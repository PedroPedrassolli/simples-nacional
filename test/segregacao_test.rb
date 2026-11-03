# frozen_string_literal: true

require "test_helper"

# Segregação de receitas: LC 123/2006, art. 18, §§ 4º e 4º-A; Res. CGSN 140/2018, arts. 23 e 25.
# Valores fictícios. Os esperados foram conferidos com uma implementação independente em Python;
# as contas estão nos comentários (RBT12 de R$ 500.000,00 = 3ª faixa).
#   Anexo I: (500.000 × 9,5% − 13.860) ÷ 500.000 = 6,728%. Anexo III: 9,972%.
describe "segregação de receitas" do
  let(:atividades) { [receita("revenda", 3_000_000), receita("servicos_3", 1_000_000)] }
  let(:extras) { { periodo: "2026-03", rbt12: 50_000_000 } }

  subject { SimplesNacional.calcular(atividades:, **extras) }

  def receita(tipo, valor, *opcoes) = { tipo:, receita: valor, opcoes: }

  def erro = assert_raises(SimplesNacional::Entrada::EntradaInvalida) { subject }.message

  def passo(titulo) = subject.passos.find { |item| item.titulo.start_with?(titulo) }

  describe "com revenda e serviço no mesmo mês" do
    # 30.000 × 6,728% = 2.018,40; 10.000 × 9,972% = 997,20.
    it "calcula cada receita no seu anexo e soma" do
      assert_equal [201_840, 99_720], subject.atividades.map(&:valor)
      assert_equal 301_560, subject.das
      assert_equal([1, 3], subject.atividades.map { |apurada| apurada.tabela.numero })
    end

    it "dá o mesmo que calcular cada receita sozinha" do
      sozinhas = [[1, 3_000_000], [3, 1_000_000]].sum do |anexo, valor|
        SimplesNacional.calcular(**extras, anexo:, receita_mes: valor).das
      end
      assert_equal sozinhas, subject.das
    end

    it "junta os tributos das duas receitas, com o percentual sobre a receita total" do
      cpp = subject.tributos.find { |tributo| tributo.nome == "CPP" }
      ponderado = ((3_000_000 * Rational(6728, 100_000) * Rational(42, 100)) +
                   (1_000_000 * Rational(9972, 100_000) * Rational(434, 1000))) / 4_000_000
      assert_equal ponderado, cpp.percentual
      assert_equal %w[IRPJ CSLL Cofins PIS/Pasep CPP ICMS ISS], subject.tributos.map(&:nome)
      assert_equal Rational(301_560, 4_000_000), subject.aliquota_efetiva
    end

    it "explica cada receita num grupo e soma no fim" do
      grupos = subject.passos.map(&:grupo).uniq
      assert_equal ["Receita 1: Revenda de mercadorias", "Receita 2: Serviços do Anexo III", "Total do mês"], grupos
      assert_equal "Soma das receitas: R$ 2.018,40 + R$ 997,20 = R$ 3.015,60.", subject.passos.last.texto
      assert passo("Valor desta receita")
    end
  end

  describe "com ICMS por substituição tributária" do
    let(:atividades) { [receita("revenda", 3_000_000, "st_icms")] }

    # ICMS do Anexo I, 3ª faixa: 33,5%. 6,728% × 66,5% = 4,47412%; 30.000 × 4,47412% = 1.342,24.
    it "tira o ICMS da conta e explica o motivo" do
      assert_equal 134_224, subject.das
      refute_includes subject.atividades.first.percentuais.keys, "ICMS"
      assert_includes passo("O que").texto,
                      "Saem da conta: o ICMS (já pago por substituição tributária ou antecipação)."
      assert_includes passo("O que").fonte, "art. 25, § 8º"
    end
  end

  describe "com PIS/Pasep e Cofins monofásicos" do
    let(:atividades) { [receita("revenda", 3_000_000, "monofasico")] }

    # Cofins 12,74% + PIS/Pasep 2,76% = 15,5%: 6,728% × 84,5% × 30.000 = 1.705,55.
    it "tira a Cofins e o PIS/Pasep" do
      assert_equal 170_555, subject.das
    end
  end

  describe "com dois qualificadores na mesma receita" do
    let(:atividades) { [receita("revenda", 3_000_000, "st_icms", "monofasico")] }

    # Sem ICMS, Cofins e PIS/Pasep: 6,728% × (100% − 33,5% − 15,5%) × 30.000 = 1.029,38.
    it "tira os tributos dos dois" do
      assert_equal 102_938, subject.das
      assert_includes passo("O que").texto,
                      "o ICMS (já pago por substituição tributária ou antecipação) e a Cofins e o PIS/Pasep"
    end
  end

  describe "com ISS retido" do
    let(:atividades) { [receita("servicos_3", 1_000_000, "iss_retido")] }

    # ISS do Anexo III, 3ª faixa: 32,5%. 9,972% × 67,5% × 10.000 = 673,11.
    it "tira o ISS" do
      assert_equal 67_311, subject.das
    end
  end

  describe "com ISS retido acima do teto de 5%" do
    let(:atividades) { [receita("servicos_4", 10_000_000, "iss_retido")] }
    let(:extras) { { periodo: "2026-01", rbt12: 350_000_000 } }

    # Anexo IV, 5ª faixa: (3.500.000 × 22% − 183.780) ÷ 3.500.000 = 16,7491%; ISS 40% = 6,6997%,
    # acima de 5%: fica 5% e os federais ficam com 11,7491% (Res. CGSN 140/2018, art. 21, III, a).
    # Retido o ISS, sobra 11,7491% × 100.000 = 11.749,14.
    it "mantém nos federais a diferença do teto" do
      assert_equal 1_174_914, subject.das
    end
  end

  describe "com exportação" do
    let(:atividades) { [receita("servicos_3", 1_000_000, "exportacao")] }
    let(:extras) { { periodo: "2026-03", rbt12: 50_000_000, rbt12_exportacao: 20_000_000 } }

    # A RBT12 da exportação (200.000) é separada (art. 23): Anexo III, 2ª faixa:
    # (200.000 × 11,2% − 9.360) ÷ 200.000 = 6,52%. Sem Cofins 14,05%, PIS/Pasep 3,05% e ISS 32%:
    # 6,52% × 50,9% × 10.000 = 331,87.
    it "usa a RBT12 da exportação e tira os tributos da exportação" do
      assert_equal 33_187, subject.das
      assert_equal [2, 20_000_000], [subject.atividades.first.faixa.numero, subject.atividades.first.rbt12]
      assert_includes passo("Faixa").texto, "A RBT12 da exportação"
      assert_equal "Exportação", subject.passos.find { |item| item.grupo == "Sublimite e limite" }.titulo
    end

    describe "sem a RBT12 da exportação" do
      let(:extras) { { periodo: "2026-03", rbt12: 50_000_000 } }

      it "pede o valor" do
        assert_match(/Informe a receita de exportação dos 12 meses anteriores/, erro)
      end
    end
  end

  describe "com Fator R e exportação" do
    let(:atividades) { [receita("fator_r", 1_000_000)] }
    let(:extras) { { periodo: "2026-03", rbt12: 40_000_000, rbt12_exportacao: 10_000_000, folha12: 14_000_000 } }

    # Fator R = 140.000 ÷ (400.000 + 100.000) = 28% (art. 26, II: mercado interno e exportação) →
    # Anexo III, 3ª faixa com a RBT12 interna: (400.000 × 13,5% − 17.640) ÷ 400.000 = 9,09%.
    it "soma a exportação na RBT12 do Fator R" do
      assert_equal [3, Rational(28, 100), 90_900], [subject.anexo.numero, subject.fator_r, subject.das]
      assert_includes passo("Fator R").texto, "(mercado interno e exportação)"
    end
  end

  describe "com locação de bens móveis" do
    let(:atividades) { [receita("locacao", 1_000_000)] }

    it "usa o Anexo III sem o ISS (art. 18, § 4º, V)" do
      assert_equal 67_311, subject.das
      assert_includes passo("O que").texto, "o ISS (locação de bens móveis)"
    end
  end

  describe "com transporte intermunicipal" do
    let(:atividades) { [receita("transporte", 1_000_000)] }

    # Anexo III sem ISS (6,7311%) mais o ICMS do Anexo I na mesma faixa (6,728% × 33,5% = 2,25388%):
    # 8,98498% × 10.000 = 898,50.
    it "troca o ISS pelo ICMS do Anexo I" do
      assert_equal 89_850, subject.das
      assert_equal Rational(6728, 100_000) * Rational(335, 1000), subject.atividades.first.percentuais["ICMS"]
      assert_includes passo("O que").texto, "Entra o ICMS do Anexo I na mesma faixa: 2,2538%."
    end
  end

  describe "com entradas inválidas" do
    describe "lista vazia" do
      let(:atividades) { [] }

      it("recusa") { assert_match(/pelo menos uma receita/, erro) }
    end

    describe "mais de 10 receitas" do
      let(:atividades) { Array.new(11) { receita("revenda", 100) } }

      it("recusa") { assert_match(/no máximo 10/, erro) }
    end

    describe "tipo desconhecido" do
      let(:atividades) { [receita("revenda", 100), receita("mineração", 100)] }

      it("recusa e diz qual receita") { assert_match(/Escolha o tipo da receita 2/, erro) }
    end

    describe "qualificador que não vale para a atividade" do
      let(:atividades) { [receita("revenda", 100, "iss_retido")] }

      it "recusa e diz qual" do
        assert_match(/"iss_retido" não vale para a receita do mês \(Revenda de mercadorias\)/, erro)
      end
    end

    describe "IPI mantido em 2026" do
      let(:atividades) { [receita("industria", 100, "ipi_mantido")] }

      it("recusa, porque a indústria já é do Anexo II") { assert_match(/só muda o anexo a partir de 2027/, erro) }
    end

    describe "receita zero numa das receitas" do
      let(:atividades) { [receita("revenda", 100), receita("revenda", 0)] }

      it("recusa e diz qual") { assert_match(/A receita 2 precisa ser maior que zero/, erro) }
    end
  end
end
