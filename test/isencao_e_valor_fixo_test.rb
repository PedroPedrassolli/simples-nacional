# frozen_string_literal: true

require "test_helper"

# Isenção e redução de ICMS e ISS (Res. CGSN 140/2018, art. 35), ICMS e ISS em valor fixo
# (art. 33) e a atividade com IPI e ISS (LC 123/2006, art. 18, § 4º, VI). Valores fictícios,
# RBT12 de R$ 500.000,00 (3ª faixa). As contas esperadas foram feitas à parte, com frações:
#   Anexo I: 6,728% × 33,5% de ICMS; Anexo II: 8,0% e 32% de ICMS; Anexo III: 9,972% × 32,5% de ISS.
describe "isenção, redução e valor fixo" do
  let(:atividades) { [{ tipo: "revenda", receita: 1_000_000, opcoes: [] }] }
  let(:extras) { {} }
  let(:rbt12) { 50_000_000 }

  subject { SimplesNacional.calcular(periodo: "2026-03", rbt12:, atividades:, **extras) }

  describe "com isenção do ICMS" do
    let(:atividades) { [{ tipo: "revenda", receita: 1_000_000, opcoes: ["isencao_icms"] }] }

    it "tira o ICMS como se não existisse" do
      assert_equal 44_741, subject.das
      refute_includes subject.tributos.map(&:nome), "ICMS"
    end

    it "explica no passo dos ajustes" do
      passo = subject.passos.find { |item| item.titulo == "O que esta receita não paga no DAS" }
      assert_match(/o ICMS \(isenção dada pelo estado\)/, passo.texto)
      assert_match(/art\. 35, I/, passo.fonte)
    end
  end

  describe "com redução de 25% do ICMS" do
    let(:atividades) { [{ tipo: "revenda", receita: 1_000_000, opcoes: ["reducao_icms=25"] }] }

    it "diminui o percentual do ICMS em 25%" do
      assert_equal 61_645, subject.das
      assert_equal({ "ICMS" => Rational(1, 4) }, subject.atividades.first.atividade.reducoes)
    end

    it "mostra a conta da redução" do
      passo = subject.passos.find { |item| item.titulo == "O que esta receita não paga no DAS" }
      assert_match(/O ICMS tem redução de 25,00% \(redução dada pelo estado\): 2,2538% × \(1 − 25,00%\) = 1,6904%/,
                   passo.texto)
    end
  end

  describe "na atividade com IPI e ISS" do
    let(:atividades) { [{ tipo: "industria_iss", receita: 4_000_000, opcoes: [] }] }

    # Anexo II sem o ICMS (8% − 2,56%) + o ISS do Anexo III (3,2409%) = 8,15594%.
    it "usa o Anexo II sem o ICMS e com o ISS do Anexo III" do
      assert_equal 326_238, subject.das
      assert_equal %w[IRPJ CSLL Cofins PIS/Pasep CPP IPI ISS], subject.tributos.map(&:nome)
    end

    it "diz de onde vem o ISS" do
      passo = subject.passos.find { |item| item.titulo == "O que esta receita não paga no DAS" }
      assert_match(/Entra o ISS do Anexo III na mesma faixa: 3,2409%/, passo.texto)
    end
  end

  describe "com redução de 40% do ISS na atividade com IPI e ISS" do
    let(:atividades) { [{ tipo: "industria_iss", receita: 4_000_000, opcoes: ["reducao_iss=40"] }] }

    it "reduz o ISS que veio do Anexo III" do
      assert_equal 274_383, subject.das
    end
  end

  describe "com o ISS em valor fixo" do
    let(:atividades) { [{ tipo: "servicos_3", receita: 2_000_000, opcoes: [] }] }
    let(:rbt12) { 20_000_000 }
    let(:extras) { { valores_fixos: { "ISS" => 40_000 }, receita_ano_anterior: 15_000_000 } }

    # RBT12 de R$ 200.000,00 (2ª faixa), sem o ISS: R$ 886,72; mais R$ 400,00 de ISS fixo.
    it "tira o percentual do ISS e soma o valor fixo ao DAS" do
      assert_equal 128_672, subject.das
      assert_equal ["ISS (valor fixo)", 40_000], subject.tributos.last.to_h.values_at(:nome, :valor)
    end

    it "mostra o valor fixo na soma e na alíquota média" do
      assert_match(/R\$ 886,72 \+ R\$ 400,00 \(ISS em valor fixo\) = R\$ 1\.286,72/, subject.passos.last.texto)
      assert_equal Rational(128_672, 2_000_000), subject.aliquota_efetiva.round(10)
    end

    it "avisa que o valor passa do máximo da faixa" do
      avisos = SimplesNacional::Avisos.montar(subject)
      assert_equal 1, avisos.size
      assert_match(/passa do máximo de R\$ 162,75/, avisos.first)
    end
  end

  describe "com valor fixo fora das regras do art. 33" do
    let(:atividades) { [{ tipo: "revenda", receita: 1_000_000, opcoes: [] }] }
    let(:extras) do
      { valores_fixos: { "ICMS" => 10_000 }, receita_ano_anterior: 40_000_000, receita_ano: 37_000_000,
        periodo: "2026-03" }
    end

    subject { SimplesNacional.calcular(rbt12: 50_000_000, atividades:, **extras) }

    it "avisa da receita do ano anterior e da receita do ano" do
      avisos = SimplesNacional::Avisos.montar(subject).join(" ")
      assert_match(/até R\$ 360\.000,00 no ano anterior/, avisos)
      assert_match(/passou de R\$ 360\.000,00/, avisos)
    end
  end

  describe "com valor fixo no ano de início" do
    let(:extras) { { valores_fixos: { "ICMS" => 10_000 }, inicio: "2026-01" } }

    subject { SimplesNacional.calcular(periodo: "2026-03", rbt12: 2_000_000, atividades:, **extras) }

    it "avisa que a ME não pode usar o valor fixo no ano de início" do
      assert_match(/ano de início/, SimplesNacional::Avisos.montar(subject).join(" "))
    end
  end

  describe "com entradas erradas" do
    def calcular(**mudancas)
      SimplesNacional.calcular(periodo: "2026-03", rbt12: 50_000_000, atividades:, **mudancas)
    end

    def erro(&) = assert_raises(SimplesNacional::Entrada::EntradaInvalida, &).message

    it "recusa redução sem percentual, de 100% ou maior" do
      %w[reducao_icms reducao_icms=100 reducao_icms=abc reducao_icms=0].each do |opcao|
        texto = erro { calcular(atividades: [{ tipo: "revenda", receita: 1_000, opcoes: [opcao] }]) }
        assert_match(/percentual da redução da receita do mês/, texto, opcao)
      end
    end

    it "recusa isenção e redução do mesmo imposto juntas" do
      opcoes = %w[isencao_iss reducao_iss=10]
      assert_match(/isenção ou redução do mesmo imposto/, erro do
        calcular(atividades: [{ tipo: "servicos_3", receita: 1_000, opcoes: }])
      end)
    end

    it "recusa redução de ICMS em serviço" do
      assert_match(/não vale para a receita/, erro do
        calcular(atividades: [{ tipo: "servicos_3", receita: 1_000, opcoes: ["reducao_icms=5"] }])
      end)
    end

    it "recusa valor fixo de outro tributo ou sem valor" do
      assert_match(/só existe para o ICMS e o ISS/, erro { calcular(valores_fixos: { "CPP" => 100 }) })
      assert_match(/valor fixo do ISS precisa ser maior que zero/, erro { calcular(valores_fixos: { iss: 0 }) })
    end
  end
end
