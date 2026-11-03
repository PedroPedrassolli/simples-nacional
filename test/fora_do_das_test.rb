# frozen_string_literal: true

require "test_helper"

# Estimativas do que fica fora do DAS, com dados que a pessoa informa (LC 123/2006, arts. 18, § 5º-C,
# e 20; LC 116/2003, arts. 8º e 8º-A; Lei 8.212/1991, art. 22; Lei 10.666/2003, art. 10; Res. CGSN
# 140/2018, arts. 22-A e 40-C na redação da Res. CGSN 190/2026). Valores fictícios.
describe SimplesNacional::ForaDoDas do
  # Receita de 2025 acima do sublimite: o ICMS e o ISS de 2026 ficam fora do DAS.
  let(:base) { { periodo: "2026-03", rbt12: 370_000_000, receita_ano: 60_000_000, receita_ano_anterior: 370_000_000 } }
  let(:atividades) { [receita("revenda", 10_000_000), receita("servicos_3", 5_000_000)] }
  let(:fora) { {} }

  subject { SimplesNacional.calcular(**base, atividades:, fora_do_das: fora) }

  def receita(tipo, valor, *opcoes) = { tipo:, receita: valor, opcoes: }

  def estimativa(tributo) = subject.fora_do_das.find { |item| item.tributo == tributo }

  def erro = assert_raises(SimplesNacional::Entrada::EntradaInvalida) { subject }.message

  describe "sem as alíquotas" do
    it "lista o ISS e o ICMS e diz o que falta" do
      assert_equal %w[ISS ICMS], subject.fora_do_das.map(&:tributo)
      assert_equal "Informe a alíquota do município (de 2% a 5%) para estimar.", estimativa("ISS").falta
      assert_nil estimativa("ICMS").valor
      assert_equal subject.das, subject.total_estimado
    end
  end

  describe "com as alíquotas e os créditos" do
    let(:fora) { { aliquota_iss: Rational(3, 100), aliquota_icms: Rational(18, 100), creditos_icms: 500_000 } }

    # ISS: 50.000 × 3% = 1.500,00. ICMS: 100.000 × 18% − 5.000 = 13.000,00.
    it "estima cada um e soma ao DAS no total" do
      assert_equal [150_000, 1_300_000], [estimativa("ISS").valor, estimativa("ICMS").valor]
      assert_equal subject.das + 1_450_000, subject.total_estimado
      assert_includes estimativa("ICMS").texto, "R$ 100.000,00 × 18,00% − R$ 5.000,00 de créditos = R$ 13.000,00"
    end

    it "mostra as estimativas no passo a passo" do
      titulos = subject.passos.select { |passo| passo.grupo == "Fora do DAS" }.map(&:titulo)
      assert_equal ["ISS fora do DAS", "ICMS fora do DAS"], titulos
    end
  end

  describe "com créditos maiores que o imposto" do
    let(:fora) { { aliquota_icms: Rational(18, 100), creditos_icms: 9_000_000 } }

    it("não deixa negativo") do
      assert_equal 0, estimativa("ICMS").valor
      assert_includes estimativa("ICMS").texto, "os créditos cobrem o imposto do mês"
    end
  end

  describe "com ICMS por substituição tributária e ISS retido" do
    let(:atividades) { [receita("revenda", 10_000_000, "st_icms"), receita("servicos_3", 5_000_000, "iss_retido")] }

    it("não estima o que já foi pago") { assert_empty subject.fora_do_das }
  end

  describe "com serviços do Anexo IV" do
    let(:base) { { periodo: "2026-01", rbt12: 50_000_000 } }
    let(:atividades) { [receita("servicos_4", 5_000_000)] }
    let(:fora) { { folha_empregados: 3_000_000, pro_labore: 500_000, rat: 2, fap: Rational(3, 2) } }

    # 30.000 × (20% + 2% × 1,5) + 5.000 × 20% = 6.900 + 1.000 = 7.900,00.
    it "estima a CPP pela folha, o RAT e o FAP" do
      assert_equal 790_000, estimativa("CPP").valor
      assert_includes estimativa("CPP").texto, "R$ 30.000,00 × (20% + 2% × FAP 1,5000) + R$ 5.000,00 de pró-labore"
      assert_equal subject.das + 790_000, subject.total_estimado
    end

    describe "sem a folha" do
      let(:fora) { {} }

      it("diz o que falta") { assert_match(/Informe a folha dos empregados e o pró-labore/, estimativa("CPP").falta) }
    end

    describe "sem o RAT" do
      let(:fora) { { folha_empregados: 3_000_000 } }

      it("pede o RAT") { assert_match(/Informe o RAT/, estimativa("CPP").falta) }
    end

    describe "só com pró-labore, sem RAT nem FAP" do
      let(:fora) { { pro_labore: 500_000 } }

      it("calcula 20% do pró-labore") { assert_equal 100_000, estimativa("CPP").valor }
    end

    describe "com outras atividades" do
      let(:atividades) { [receita("servicos_4", 5_000_000), receita("revenda", 1_000_000)] }

      it("avisa que a conta usa a folha inteira") { assert_includes estimativa("CPP").texto, "folha inteira" }
    end
  end

  describe "com o IBS e a CBS no regime regular (2027)" do
    let(:base) { { periodo: "2027-01", rbt12: 50_000_000, ibs_cbs_fora: true } }
    let(:atividades) { [receita("revenda", 10_000_000), receita("servicos_3", 5_000_000, "exportacao")] }
    let(:fora) { { aliquota_cbs: Rational(88, 1000), creditos_cbs: 300_000 } }

    # Só a receita interna paga: CBS = 100.000 × 8,8% − 3.000 = 5.800,00. Sem a alíquota do IBS, ele fica
    # sem estimativa.
    it "estima a CBS e pede a alíquota do IBS" do
      base[:rbt12_exportacao] = 0
      assert_equal [580_000, nil], [estimativa("CBS").valor, estimativa("IBS").valor]
      assert_equal "Informe a alíquota do IBS para estimar.", estimativa("IBS").falta
    end
  end

  # Valores fictícios: R$ 100,00 com MVA de 40%, ICMS interno de 18% no destino e 12% na
  # operação própria. Contas à parte: 140,00 × 18% − 12,00 = 13,20; com R$ 10,00 de IPI,
  # 154,00 × 18% − 12,00 = 15,72.
  describe "com ICMS por substituição tributária como substituta" do
    let(:st) do
      { st_valor: 10_000, st_mva: Rational(40, 100), st_aliquota_interna: Rational(18, 100),
        st_aliquota_propria: Rational(12, 100) }
    end
    let(:fora) { st }

    it "estima pela base com a MVA menos o ICMS próprio" do
      assert_equal [14_000, 1_320], estimativa("ICMS-ST").to_h.values_at(:base, :valor)
      assert_match(/R\$ 140,00 × 18,00% − R\$ 12,00 \(12,00% da operação própria\) = R\$ 13,20/,
                   estimativa("ICMS-ST").texto)
    end

    describe "com IPI e encargos" do
      let(:fora) { st.merge(st_ipi: 1_000) }

      it("soma o IPI à base") { assert_equal 1_572, estimativa("ICMS-ST").valor }
    end

    describe "com a alíquota própria maior que a interna" do
      let(:fora) { st.merge(st_mva: Rational(1, 100), st_aliquota_interna: Rational(7, 100)) }

      it("não fica negativo") { assert_equal 0, estimativa("ICMS-ST").valor }
    end

    describe "sem a MVA" do
      let(:fora) { st.except(:st_mva) }

      it "diz o que falta" do
        assert_equal ["Informe a MVA para estimar.", nil], estimativa("ICMS-ST").to_h.values_at(:falta, :valor)
      end
    end
  end

  # R$ 100,00 de compras de outro estado, 17,5% interna e 12% interestadual: 100,00 × 5,5% = 5,50.
  describe "com diferencial de alíquota" do
    let(:difal) do
      { difal_valor: 10_000, difal_aliquota_interna: Rational(175, 1000),
        difal_aliquota_interestadual: Rational(12, 100) }
    end
    let(:fora) { difal }

    it "estima pela diferença das alíquotas" do
      assert_equal 550, estimativa("DIFAL").valor
      assert_match(/R\$ 100,00 × \(17,50% − 12,00%\) = R\$ 5,50/, estimativa("DIFAL").texto)
    end

    describe "com a interestadual maior que a interna" do
      let(:fora) { difal.merge(difal_aliquota_interestadual: Rational(18, 100)) }

      it("não fica negativo") { assert_equal 0, estimativa("DIFAL").valor }
    end

    describe "sem a alíquota interestadual" do
      let(:fora) { difal.except(:difal_aliquota_interestadual) }

      it "diz o que falta" do
        assert_equal "Informe a alíquota interestadual do ICMS para estimar.", estimativa("DIFAL").falta
      end
    end
  end

  describe "com valores inválidos" do
    {
      { aliquota_iss: Rational(6, 100) } => /A alíquota do ISS precisa ser maior que zero e no máximo 5,00%/,
      { aliquota_icms: 0.18 } => /A alíquota do ICMS precisa ser maior que zero/,
      { creditos_icms: -1 } => /A soma dos créditos de ICMS não pode ser negativa/,
      { rat: 4 } => /O RAT precisa ser 1, 2 ou 3/,
      { fap: Rational(3) } => /O FAP precisa estar entre 0,5 e 2,0/,
      { st_mva: 6 } => /A MVA precisa ser maior que zero e no máximo 500,00%/,
      { difal_valor: -1 } => /A soma das compras de outros estados não pode ser negativa/,
      { aliquota_pis: 1 } => /Campo desconhecido fora do DAS: aliquota_pis/
    }.each do |valores, mensagem|
      describe valores.keys.first.to_s do
        let(:fora) { valores }

        it("recusa") { assert_match(mensagem, erro) }
      end
    end
  end
end
