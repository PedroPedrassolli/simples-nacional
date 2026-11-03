# frozen_string_literal: true

require "test_helper"

# DAS do MEI (LC 123/2006, art. 18-A; Res. CGSN 140/2018, arts. 100, 101 e 115). Salário
# mínimo de 2026: R$ 1.621,00 (Decreto 12.797/2025). Valores fictícios.
describe SimplesNacional::Mei do
  let(:entrada) { { periodo: "2026-03", atividade: "comercio" } }

  subject { SimplesNacional.calcular_mei(**entrada) }

  describe "em 2026" do
    it "soma 5% do salário mínimo e o ICMS de quem vende mercadorias" do
      assert_equal([["INSS", 8_105], ["ICMS", 100]], subject.tributos.map { |tributo| [tributo.nome, tributo.valor] })
      assert_equal 8_205, subject.das
    end

    it "cobra o ISS de quem presta serviços e os dois de quem faz os dois" do
      assert_equal 8_605, SimplesNacional.calcular_mei(**entrada, atividade: "servicos").das
      assert_equal 8_705, SimplesNacional.calcular_mei(**entrada, atividade: "comercio_servicos").das
    end

    it "cobra 12% do salário mínimo do transportador autônomo de cargas" do
      assert_equal 19_952, SimplesNacional.calcular_mei(**entrada, atividade: "servicos", transportador: true).das
    end

    it "explica a conta com a base legal" do
      textos = subject.passos.map(&:texto)
      assert_match(/5% × R\$ 1\.621,00 \(Decreto nº 12\.797, de 23 de dezembro de 2025\) = R\$ 81,05/, textos[0])
      assert_match(/O ICMS é de quem vende mercadorias/, textos[1])
      assert_match(/R\$ 81,05 \+ R\$ 1,00 = R\$ 82,05/, textos[2])
      assert_equal ["DAS do MEI"], subject.passos.map(&:grupo).uniq
    end
  end

  describe "em 2027, sem o decreto do salário mínimo" do
    let(:entrada) { { periodo: "2027-03", atividade: "comercio_servicos", salario_minimo: 170_000 } }

    it "usa o salário mínimo informado e soma a CBS e o IBS do Anexo VII" do
      nomes = subject.tributos.map(&:nome)
      assert_equal %w[INSS ICMS ISS CBS IBS], nomes
      assert_equal [Rational(497, 5), Rational(3, 5)], subject.tributos.last(2).map(&:valor)
      assert_equal 9_200, subject.das
    end

    it "mostra os milésimos da CBS e do IBS e a fonte da LC 214/2025" do
      passo = subject.passos[1]
      assert_match(/CBS R\$ 0,994 e IBS R\$ 0,006/, passo.texto)
      assert_match(%r{Anexo VII \(LC 214/2025}, passo.fonte)
      assert_match(/valor informado: o decreto de 2027 ainda não saiu/, subject.passos.first.texto)
    end

    it "pede o salário mínimo quando ele não veio" do
      erro = assert_raises(SimplesNacional::Entrada::EntradaInvalida) { SimplesNacional.calcular_mei(**entrada, salario_minimo: nil) }
      assert_match(/salário mínimo de 2027 ainda não foi publicado/, erro.message)
    end
  end

  describe "com a receita do ano" do
    it "diz que está dentro do limite" do
      limite = SimplesNacional.calcular_mei(**entrada, receita_ano: 8_000_000).limite
      assert_equal [8_100_000, 0, :dentro], [limite.limite, limite.excesso, limite.situacao]
    end

    # Início em abril: R$ 6.750,00 × 9 = R$ 60.750,00. Excesso de R$ 4.250,00 × 4% (1ª faixa do Anexo I).
    it "usa o limite proporcional no ano de início e estima a diferença sobre o excesso" do
      resultado = SimplesNacional.calcular_mei(**entrada, periodo: "2026-10", inicio: "2026-04", receita_ano: 6_500_000)
      limite = resultado.limite
      assert_equal [6_075_000, 425_000, 17_000, :ate_vinte_por_cento],
                   limite.to_h.values_at(:limite, :excesso, :diferenca, :situacao)
      assert_match(/Diferença estimada sobre o excesso, pela 1ª faixa do anexo: R\$ 170,00/, resultado.passos[3].texto)
    end

    it "manda apurar como ME com excesso de mais de 20%" do
      resultado = SimplesNacional.calcular_mei(**entrada, receita_ano: 10_000_000)
      assert_equal [nil, :desde_janeiro], [resultado.limite.diferenca, resultado.limite.situacao]
      assert_match(/volta a 1º de janeiro/, resultado.passos[3].texto)
    end

    it "volta ao início das atividades com excesso de mais de 20% no ano de início" do
      assert_equal :desde_o_inicio,
                   SimplesNacional.calcular_mei(**entrada, inicio: "2026-02", receita_ano: 9_000_000).limite.situacao
    end

    it "não estima a diferença de quem tem comércio e serviços" do
      limite = SimplesNacional.calcular_mei(**entrada, atividade: "comercio_servicos", receita_ano: 8_500_000).limite
      assert_equal [400_000, nil], [limite.excesso, limite.diferenca]
    end

    # A partir de 2027, a indústria usa o Anexo I (4% na 1ª faixa).
    it "usa o anexo da indústria do ano" do
      limite = SimplesNacional.calcular_mei(periodo: "2027-03", atividade: "industria", salario_minimo: 170_000,
                                            receita_ano: 8_200_000).limite
      assert_equal 4_000, limite.diferenca
    end

    it "usa o limite do transportador autônomo de cargas, proporcional no ano de início" do
      limite = SimplesNacional.calcular_mei(**entrada, periodo: "2026-10", transportador: true, inicio: "2026-07",
                                                       receita_ano: 1_000).limite
      assert_equal 12_580_002, limite.limite
      assert_equal 25_160_000,
                   SimplesNacional.calcular_mei(**entrada, transportador: true, receita_ano: 1_000).limite.limite
    end
  end

  describe "com pagamento em atraso" do
    it "soma a multa e os juros ao DAS do MEI" do
      resultado = SimplesNacional.calcular_mei(**entrada, pagamento: "2026-04-25")
      assert_equal [135, 0], [resultado.atraso.multa, resultado.atraso.juros] # 1,65% de R$ 82,05
      assert_equal "Multa e juros", resultado.passos.last.titulo
    end
  end

  describe "com entradas erradas" do
    def erro(**mudancas)
      assert_raises(SimplesNacional::Entrada::EntradaInvalida) do
        SimplesNacional.calcular_mei(**entrada, **mudancas)
      end.message
    end

    it "recusa atividade, mês e início que não servem" do
      assert_equal "Escolha a atividade do MEI.", erro(atividade: "outra")
      assert_match(/AAAA-MM/, erro(periodo: "março"))
      assert_match(/de 2026 a 2028/, erro(periodo: "2029-01"))
      assert_match(/não pode ser depois do mês/, erro(inicio: "2026-05"))
    end

    it "recusa início em outro formato, receita negativa e salário mínimo zero" do
      assert_match(/início no formato AAAA-MM/, erro(inicio: "abril"))
      assert_match(/não pode ser negativa/, erro(receita_ano: -1))
      assert_match(/salário mínimo precisa ser maior que zero/, erro(periodo: "2027-01", salario_minimo: 0))
    end
  end
end
