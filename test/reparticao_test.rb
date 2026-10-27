# frozen_string_literal: true

require "test_helper"

# Contas feitas à mão com os percentuais de repartição dos Anexos da LC 123/2006 e a
# Resolução CGSN 140/2018, art. 21, III. Receitas fictícias.
describe SimplesNacional::Reparticao do
  let(:tabelas) { SimplesNacional::Calculo.tabelas }

  # Percentuais de um anexo para uma RBT12 (em centavos), pelo mesmo caminho do cálculo.
  def percentuais(anexo, rbt12)
    tabela = tabelas.fetch(anexo)
    faixa = tabela.faixas.find { |item| rbt12 <= item.ate * 100 }
    efetiva = SimplesNacional::Calculo.aliquota_efetiva(faixa, rbt12)
    SimplesNacional::Reparticao.percentuais(tabela, faixa, rbt12, efetiva)
  end

  def porcento(texto) = Rational(texto) / 100

  it "divide a alíquota efetiva pelos percentuais da faixa" do
    # Anexo III, 3ª faixa, RBT12 de R$ 500.000,00: alíquota efetiva de 9,972%.
    resultado = percentuais(3, 50_000_000)
    assert_equal porcento("9.972") * porcento("4.00"), resultado["IRPJ"]
    assert_equal porcento("9.972") * porcento("32.50"), resultado["ISS"]
    assert_equal porcento("9.972"), resultado.values.sum
  end

  it "inclui o IPI no Anexo II e deixa a CPP de fora no Anexo IV" do
    assert_equal %w[IRPJ CSLL Cofins PIS/Pasep CPP IPI ICMS], percentuais(2, 10_000_000).keys
    assert_equal %w[IRPJ CSLL Cofins PIS/Pasep ISS], percentuais(4, 10_000_000).keys
  end

  describe "com o ISS acima de 5%" do
    # Anexo III, 5ª faixa, RBT12 de R$ 3.600.000,00: (3.600.000 × 21% − 125.640) ÷ 3.600.000 = 17,51%.
    # O ISS daria 17,51% × 33,5% = 5,86585%; pela nota do anexo, fica 5% e cada federal leva
    # (17,51% − 5%) × o percentual da nota: IRPJ 6,02%.
    it "usa a repartição da nota do anexo na 5ª faixa" do
      resultado = percentuais(3, 360_000_000)
      assert_equal porcento("5"), resultado["ISS"]
      irpj = (porcento("17.51") - porcento("5")) * porcento("6.02")
      assert_equal irpj, resultado["IRPJ"]
      assert_equal porcento("17.51"), resultado.values.sum
    end

    # Anexo V, 5ª faixa, no limite: (3.600.000 × 23% − 62.100) ÷ 3.600.000 = 21,275%; × 23,5% = 4,9996%.
    it "não mexe no ISS que fica abaixo de 5%" do
      assert_equal porcento("21.275") * porcento("23.50"), percentuais(5, 360_000_000)["ISS"]
    end
  end

  describe "na 6ª faixa" do
    # Anexo I, RBT12 de R$ 4.000.000,00. Federais: (4.000.000 × 19% − 378.000) ÷ 4.000.000 = 9,55%.
    # ICMS pela 5ª faixa: (4.000.000 × 14,3% − 87.300) ÷ 4.000.000 = 12,1175%; × 33,5%.
    it "calcula o ICMS com a 5ª faixa e soma aos federais" do
      resultado = percentuais(1, 400_000_000)
      assert_equal porcento("9.55") * porcento("13.50"), resultado["IRPJ"]
      assert_equal porcento("12.1175") * porcento("33.50"), resultado["ICMS"]
      assert_equal porcento("9.55") + (porcento("12.1175") * porcento("33.50")), resultado.values.sum
    end

    # Anexo III, RBT12 de R$ 4.800.000,00. Federais: (4.800.000 × 33% − 648.000) ÷ 4.800.000 = 19,5%.
    # ISS pela 5ª faixa: (4.800.000 × 21% − 125.640) ÷ 4.800.000 = 18,3825%; × 33,5% = 6,1581375%.
    # Fica 5%, e os federais dividem 19,5% + 6,1581375% − 5% pelos percentuais da 6ª faixa.
    it "aplica o teto do ISS com os pesos da própria faixa" do
      resultado = percentuais(3, 480_000_000)
      resto = porcento("19.5") + porcento("6.1581375") - porcento("5")
      assert_equal porcento("5"), resultado["ISS"]
      assert_equal resto * porcento("35.00"), resultado["IRPJ"]
      assert_equal resto * porcento("30.50"), resultado["CPP"]
    end
  end

  it "descobre o imposto local de cada anexo" do
    locais = (1..5).map { |numero| SimplesNacional::Reparticao.imposto_local(tabelas[numero]) }
    assert_equal %w[ICMS ICMS ISS ISS ISS], locais
  end
end
