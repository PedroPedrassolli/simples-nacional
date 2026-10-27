# frozen_string_literal: true

require "test_helper"

# Os valores de exemplo são fictícios. As contas esperadas foram feitas à mão a partir
# das tabelas da LC 123/2006 (data/anexos/), sem usar o código que está sendo testado.
describe SimplesNacional::Calculo do
  let(:entrada) { { rbt12: 50_000_000, receita_mes: 4_000_000, anexo: 3 } }

  subject { SimplesNacional.calcular(**entrada) }

  def erro(**mudancas)
    assert_raises(SimplesNacional::Calculo::EntradaInvalida) { SimplesNacional.calcular(**entrada, **mudancas) }.message
  end

  describe "com uma conta feita à mão" do
    # Anexo III, 3ª faixa: (500.000 × 13,5% − 17.640) ÷ 500.000 = 9,972%; 40.000 × 9,972% = 3.988,80.
    it "calcula a alíquota efetiva e o DAS no Anexo III" do
      assert_equal Rational(9972, 100_000), subject.aliquota_efetiva
      assert_equal 398_880, subject.das
    end

    describe "no Anexo I, 2ª faixa" do
      # (300.000 × 7,3% − 5.940) ÷ 300.000 = 5,32%; 25.000 × 5,32% = 1.330,00.
      let(:entrada) { { rbt12: 30_000_000, receita_mes: 2_500_000, anexo: 1 } }

      it "calcula o DAS" do
        assert_equal 133_000, subject.das
      end
    end

    describe "no Anexo V, 6ª faixa" do
      # (4.000.000 × 30,5% − 540.000) ÷ 4.000.000 = 17%; 300.000 × 17% = 51.000,00.
      let(:entrada) { { rbt12: 400_000_000, receita_mes: 30_000_000, anexo: 5 } }

      it "calcula o DAS" do
        assert_equal 5_100_000, subject.das
      end
    end
  end

  describe "em cada faixa de cada anexo" do
    it "usa a faixa até o limite dela, inclusive, e a próxima a partir de 1 centavo a mais" do
      SimplesNacional::Calculo.tabelas.each_value do |tabela|
        tabela.faixas.each_cons(2) do |faixa, proxima|
          limite = SimplesNacional::Calculo.centavos(faixa.ate)
          no_limite = SimplesNacional.calcular(rbt12: limite, receita_mes: 100, anexo: tabela.numero)
          depois = SimplesNacional.calcular(rbt12: limite + 1, receita_mes: 100, anexo: tabela.numero)
          assert_equal [faixa.numero, proxima.numero], [no_limite.faixa.numero, depois.faixa.numero]
        end
      end
    end

    it "na 1ª faixa, a alíquota efetiva é igual à nominal (não há parcela a deduzir)" do
      SimplesNacional::Calculo.tabelas.each_value do |tabela|
        resultado = SimplesNacional.calcular(rbt12: 10_000_000, receita_mes: 100, anexo: tabela.numero)
        assert_equal tabela.faixas.first.aliquota, resultado.aliquota_efetiva
      end
    end

    it "aceita a RBT12 exatamente no limite da empresa de pequeno porte" do
      assert_equal 6, SimplesNacional.calcular(**entrada, rbt12: SimplesNacional::Calculo::TETO).faixa.numero
    end
  end

  describe "com o DAS quebrado em frações de centavo" do
    # 4% de R$ 12,38 = 49,52 centavos → R$ 0,50.
    let(:entrada) { { rbt12: 10_000_000, receita_mes: 1238, anexo: 1 } }

    it "arredonda para o centavo mais próximo" do
      assert_equal 50, subject.das
    end
  end

  describe "os passos da conta" do
    it "explicam o anexo, a faixa, a alíquota efetiva e o DAS, nessa ordem" do
      assert_equal ["Anexo", "Faixa", "Alíquota efetiva", "DAS estimado"], subject.passos.map(&:titulo)
    end

    it "mostram os números da conta no formato brasileiro" do
      assert_includes subject.passos[2].texto, "(R$ 500.000,00 × 13,50% − R$ 17.640,00) ÷ R$ 500.000,00 = 9,9720%"
      assert_includes subject.passos[3].texto, "R$ 40.000,00 × 9,9720% = R$ 3.988,80"
    end

    it "mostram os limites da faixa" do
      assert_includes subject.passos[1].texto, "3ª faixa do Anexo III, de R$ 360.000,01 a R$ 720.000,00"
    end

    it "trazem a base legal de cada passo" do
      assert_equal "LC 123/2006, art. 18, § 1º-A", subject.passos[2].fonte
    end

    describe "na 1ª faixa" do
      let(:entrada) { { rbt12: 10_000_000, receita_mes: 100, anexo: 2 } }

      it "mostra só o limite de cima" do
        assert_includes subject.passos[1].texto, "1ª faixa do Anexo II, até R$ 180.000,00"
      end
    end
  end

  describe "com entradas inválidas" do
    it "recusa RBT12 negativa" do
      assert_match(/RBT12\) precisa ser maior que zero/, erro(rbt12: -1))
    end

    it "recusa RBT12 zero" do
      assert_match(/maior que zero/, erro(rbt12: 0))
    end

    it "recusa receita do mês zero" do
      assert_match(/A receita do mês precisa ser maior que zero/, erro(receita_mes: 0))
    end

    it "recusa texto no lugar de número" do
      assert_match(/número inteiro de centavos/, erro(rbt12: "500000"))
    end

    it "recusa número com casas decimais (Float)" do
      assert_match(/número inteiro de centavos/, erro(receita_mes: 40_000.5))
    end

    it "recusa RBT12 acima do limite do Simples" do
      assert_match(/passa de R\$ 4\.800\.000,00/, erro(rbt12: SimplesNacional::Calculo::TETO + 1))
    end

    it "recusa receita do mês acima do limite do Simples" do
      assert_match(/A receita do mês passa de/, erro(receita_mes: SimplesNacional::Calculo::TETO + 1))
    end

    it "recusa anexo que não existe" do
      assert_match(/1, 2, 3, 4 ou 5/, erro(anexo: 6))
    end

    it "recusa anexo escrito como texto" do
      assert_match(/1, 2, 3, 4 ou 5/, erro(anexo: "3"))
    end
  end

  describe "o limite do Simples" do
    it "é o mesmo da última faixa de todas as tabelas" do
      limites = SimplesNacional::Calculo.tabelas.values.map { |tabela| tabela.faixas.last.ate * 100 }
      assert_equal [SimplesNacional::Calculo::TETO], limites.uniq
    end
  end
end
