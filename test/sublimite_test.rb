# frozen_string_literal: true

require "test_helper"
require "tmpdir"

# Sublimite do ICMS e do ISS em 2026 (R$ 3.600.000,00 em todas as UFs, Portaria CGSN 54/2025;
# em 2025, Portaria CGSN 49/2024). Regras: LC 123/2006, arts. 3º, 13-A, 18, 19 e 20; Res. CGSN
# 140/2018, arts. 9º, 12, 21, 22 e 24. Valores fictícios, contas feitas à mão nos comentários.
describe SimplesNacional::Sublimite do
  def calcular(**dados) = SimplesNacional.calcular(anexo: 1, **dados)

  def erro(**dados)
    assert_raises(SimplesNacional::Entrada::EntradaInvalida) { calcular(**dados) }.message
  end

  def passo(resultado) = resultado.passos.find { |item| item.titulo.start_with?("Sublimite") }

  def porcento(texto) = Rational(texto) / 100

  it "lê o sublimite de 2025 e de 2026 com a fonte" do
    assert_equal([360_000_000, 360_000_000], [2025, 2026].map { |ano| SimplesNacional::Sublimite.valor(ano) })
    assert_match(/Portaria CGSN nº 54/, SimplesNacional::Sublimite.anos.fetch(2026)[:ato])
  end

  it "recusa outro valor de sublimite no arquivo, que pediria outra fórmula" do
    Dir.mktmpdir do |pasta|
      arquivo = File.join(pasta, "sublimite.yml")
      File.write(arquivo, { "anos" => { 2026 => { "valor" => "1800000.00" } } }.to_yaml)
      erro = assert_raises(RuntimeError) { SimplesNacional::Sublimite.ler(arquivo) }
      assert_match(/só o sublimite de R\$ 3\.600\.000,00/, erro.message)
    end
  end

  describe "longe do sublimite" do
    subject { calcular(periodo: "2026-03", rbt12: 50_000_000, receita_mes: 4_000_000) }

    it "não pede a receita do ano e não mostra o passo" do
      assert_equal :no_das, subject.situacao.tipo
      assert_nil subject.situacao.receita_ano
      assert_nil passo(subject)
    end
  end

  it "pede a receita do ano quando a RBT12 mais a receita do mês passa do sublimite" do
    assert_match(/Informe a receita bruta de 2026 até o mês anterior/,
                 erro(periodo: "2026-03", rbt12: 350_000_000, receita_mes: 20_000_000))
  end

  describe "em janeiro, com a RBT12 na 6ª faixa" do
    # A receita do ano antes de janeiro é zero. Federais: (4.000.000 × 19% − 378.000) ÷ 4.000.000 = 9,55%;
    # ICMS pela 5ª faixa: (4.000.000 × 14,3% − 87.300) ÷ 4.000.000 × 33,5% = 4,0593625%.
    # 400.000 × 13,6093625% = 54.437,45.
    subject { calcular(periodo: "2026-01", rbt12: 400_000_000, receita_mes: 40_000_000) }

    it "mantém o ICMS no DAS e avisa que considerou o ano anterior abaixo do sublimite" do
      assert_equal [:no_das, 0, 5_443_745], [subject.situacao.tipo, subject.situacao.receita_ano, subject.das]
      assert_includes passo(subject).texto, "Sem a receita de 2025, a conta considera que ela não passou do sublimite"
      assert_includes passo(subject).texto, "R$ 400.000,00: não passa do sublimite, e o ICMS fica no DAS."
    end
  end

  describe "quando a receita do ano passa do sublimite neste mês" do
    # Outubro: 3.300.000 até setembro + 400.000 = 3.700.000, 100.000 acima de 3.600.000 → 1/4 da
    # receita do mês usa o ICMS do art. 24, I: (3.600.000 × 14,3% − 87.300) ÷ 3.600.000 × 33,5% = 3,978125%.
    # Os outros 3/4 seguem a 6ª faixa (RBT12 de 3.900.000): federais 363.000 ÷ 3.900.000 e ICMS
    # 470.400 ÷ 3.900.000 × 33,5%.
    subject do
      calcular(periodo: "2026-10", rbt12: 390_000_000, receita_mes: 40_000_000, receita_ano: 330_000_000,
               receita_ano_anterior: 350_000_000)
    end

    it "usa o percentual do art. 24 só na parte acima do sublimite" do
      icms = (Rational(3, 4) * Rational(470_400, 3_900_000) * porcento("33.5")) +
             (Rational(1, 4) * porcento("3.978125"))
      total = Rational(363_000, 3_900_000) + icms
      assert_equal [:majorado, Rational(1, 4), :pouco_acima], subject.situacao.to_h.values_at(:tipo, :fracao, :motivo)
      assert_equal (40_000_000 * total).round(half: :up), subject.das
      assert_equal 5_333_074, subject.das
    end

    it "explica a parte, o percentual e quando o ICMS sai do DAS" do
      texto = passo(subject).texto
      assert_includes texto, "A receita de 2025 não passou do sublimite."
      assert_includes texto, "A parte da receita do mês acima dele, R$ 100.000,00, paga o ICMS"
      assert_includes texto, "3,9781%. Pelo tamanho do excesso, o ICMS sai do DAS só no ano seguinte."
      assert_equal "LC 123/2006, art. 18, §§ 17 e 17-A; Res. CGSN 140/2018, arts. 12 e 24, I", passo(subject).fonte
      assert_match(/segue outra regra/, SimplesNacional::PassoDoSublimite.aviso(subject.anexo, subject.situacao))
    end
  end

  describe "quando a receita do ano já passou do sublimite, mas não de 20% dele" do
    # 3.800.000 até setembro + 600.000 = 4.400.000: acima de 4.320.000 (20% a mais), então o ICMS
    # sai do DAS no mês seguinte. Neste mês, toda a receita usa o ICMS do art. 24: 3,978125%.
    # Federais da 6ª faixa (RBT12 de 4.200.000): (798.000 − 378.000) ÷ 4.200.000 = 10%.
    # 600.000 × 13,978125% = 83.868,75.
    subject { calcular(periodo: "2026-10", rbt12: 420_000_000, receita_mes: 60_000_000, receita_ano: 380_000_000) }

    it "usa o percentual do art. 24 em toda a receita do mês" do
      assert_equal [:majorado, 1, :muito_acima], subject.situacao.to_h.values_at(:tipo, :fracao, :motivo)
      assert_equal 8_386_875, subject.das
      assert_includes passo(subject).texto, "Toda a receita do mês paga o ICMS"
      assert_includes passo(subject).texto, "o ICMS sai do DAS a partir do mês seguinte."
    end
  end

  describe "no ISS acima do sublimite" do
    # Anexo III: (3.600.000 × 21% − 125.640) ÷ 3.600.000 × 33,5% = 5,86585%, acima do teto de 5%.
    subject do
      calcular(anexo: 3, periodo: "2026-10", rbt12: 380_000_000, receita_mes: 10_000_000, receita_ano: 370_000_000)
    end

    it "limita o ISS a 5%" do
      iss = subject.tributos.find { |tributo| tributo.nome == "ISS" }
      assert_equal porcento("5"), iss.percentual
      assert_includes passo(subject).texto, "5,8658% (o ISS fica limitado a 5%)"
    end
  end

  describe "com a receita do ano mais de 20% acima do sublimite antes deste mês" do
    # 4.400.000 até setembro > 4.320.000: o ISS já saiu do DAS. Anexo III, 6ª faixa, só federais:
    # (4.500.000 × 33% − 648.000) ÷ 4.500.000 = 18,6%; 100.000 × 18,6% = 18.600,00.
    subject do
      calcular(anexo: 3, periodo: "2026-10", rbt12: 450_000_000, receita_mes: 10_000_000, receita_ano: 440_000_000)
    end

    it "tira o ISS do DAS e avisa" do
      assert_equal [:fora, :excesso, 1_860_000], [subject.situacao.tipo, subject.situacao.motivo, subject.das]
      refute_includes subject.tributos.map(&:nome), "ISS"
      assert_includes passo(subject).texto, "já tinha passado do sublimite em mais de 20%"
      assert_match(/não entra no DAS.*município/, SimplesNacional::PassoDoSublimite.aviso(subject.anexo,
                                                                                          subject.situacao))
      refute_includes subject.passos.find { |item| item.titulo == "Divisão entre os tributos" }.texto, "5ª faixa"
    end
  end

  describe "com a receita do ano anterior acima do sublimite" do
    # Anexo I, 5ª faixa, ICMS fora do DAS: (3.000.000 × 14,3% − 87.300) ÷ 3.000.000 = 11,39%, sem os 33,5%
    # do ICMS: 7,57435%. 100.000 × 7,57435% = 7.574,35.
    subject do
      calcular(periodo: "2026-01", rbt12: 300_000_000, receita_mes: 10_000_000, receita_ano_anterior: 365_000_000)
    end

    it "deixa o ICMS do ano todo fora do DAS" do
      assert_equal [:fora, :ano_anterior, 757_435], [subject.situacao.tipo, subject.situacao.motivo, subject.das]
      assert_includes passo(subject).texto, "A receita de 2025, R$ 3.650.000,00, passou do sublimite."
      assert_match(/estado/, SimplesNacional::PassoDoSublimite.aviso(subject.anexo, subject.situacao))
    end
  end

  describe "no ano de início de atividade" do
    # Início em junho de 2026: sublimite de 3.600.000 ÷ 12 × 7 = 2.100.000; limite de 4.800.000 ÷ 12 × 7 =
    # 2.800.000. Junho e julho somaram a receita informada em rbt12, que é também a receita do ano.
    let(:inicio) { { periodo: "2026-08", inicio: "2026-06" } }

    it "usa o sublimite proporcional e a receita desde o início" do
      resultado = calcular(**inicio, rbt12: 100_000_000, receita_mes: 20_000_000)
      assert_equal [:no_das, 210_000_000, 100_000_000],
                   resultado.situacao.to_h.values_at(:tipo, :sublimite, :receita_ano)
      assert_includes passo(resultado).texto, "R$ 3.600.000,00 ÷ 12 × 7 = R$ 2.100.000,00"
    end

    it "usa o percentual do art. 24 acima do sublimite proporcional, até 20%" do
      # 2.000.000 + 200.000 = 2.200.000: 100.000 acima de 2.100.000, metade da receita do mês.
      resultado = calcular(**inicio, rbt12: 200_000_000, receita_mes: 20_000_000)
      assert_equal [:majorado, Rational(1, 2), :pouco_acima], resultado.situacao.to_h.values_at(:tipo, :fracao, :motivo)
    end

    it "tira o ICMS do DAS desde o início com mais de 20%" do
      # 2.000.000 + 600.000 = 2.600.000 > 2.520.000. RBT12 anualizada: 2.000.000 ÷ 2 × 12 = 12.000.000 →
      # última faixa, federais: (12.000.000 × 19% − 378.000) ÷ 12.000.000 = 15,85%; 600.000 × 15,85% = 95.100,00.
      resultado = calcular(**inicio, rbt12: 200_000_000, receita_mes: 60_000_000)
      assert_equal [:fora, :inicio, 9_510_000], [resultado.situacao.tipo, resultado.situacao.motivo, resultado.das]
      assert_includes passo(resultado).texto, "mais de 20% acima dele: o ICMS sai do DAS desde o início das atividades."
    end

    it "recusa receita acima do limite proporcional" do
      assert_match(/passa de R\$ 2\.800\.000,00, o limite do Simples Nacional no ano de início/,
                   erro(**inicio, rbt12: 250_000_000, receita_mes: 40_000_000))
    end

    it "ignora a receita do ano anterior, que a empresa não tinha" do
      resultado = calcular(**inicio, rbt12: 100_000_000, receita_mes: 20_000_000, receita_ano_anterior: 600_000_000)
      refute_includes passo(resultado).texto, "A receita de 2025"
    end
  end

  describe "com início de atividade no ano anterior" do
    # Início em julho de 2025: em 2025, sublimite de 1.800.000 e limite de 2.400.000 (6 meses).
    let(:inicio) { { periodo: "2026-03", inicio: "2025-07", rbt12: 260_000_000, receita_mes: 30_000_000 } }

    it "compara a receita de 2025 com o sublimite proporcional" do
      resultado = calcular(**inicio, receita_ano_anterior: 200_000_000)
      assert_equal %i[fora ano_anterior], [resultado.situacao.tipo, resultado.situacao.motivo]
    end

    it "recusa receita de 2025 acima do limite proporcional" do
      assert_match(/A receita de 2025 passa de R\$ 2\.400\.000,00/, erro(**inicio, receita_ano_anterior: 250_000_000))
    end
  end

  describe "com valores que não fecham" do
    it "recusa a receita do ano acima do limite de R$ 4.800.000,00" do
      assert_match(/A receita de 2026 passa de R\$ 4\.800\.000,00.*a empresa sai do regime/,
                   erro(periodo: "2026-10", rbt12: 450_000_000, receita_mes: 50_000_000, receita_ano: 440_000_000))
    end

    it "recusa a receita do ano anterior acima do limite" do
      assert_match(/A receita de 2025 passa de R\$ 4\.800\.000,00/,
                   erro(periodo: "2026-03", rbt12: 50_000_000, receita_mes: 100, receita_ano_anterior: 480_000_001))
    end

    it "recusa a receita do ano maior que a RBT12" do
      assert_match(/não pode ser maior que a receita dos meses anteriores/,
                   erro(periodo: "2026-10", rbt12: 350_000_000, receita_mes: 50_000_000, receita_ano: 360_000_000))
    end

    it "recusa a receita do ano anterior menor que a parte dela dentro da RBT12" do
      # Janeiro: a RBT12 é toda de 2025.
      assert_match(/A receita de 2025 não pode ser menor que a parte dela dentro da RBT12 \(R\$ 4\.000\.000,00\)/,
                   erro(periodo: "2026-01", rbt12: 400_000_000, receita_mes: 100, receita_ano_anterior: 350_000_000))
    end

    it "aceita a RBT12 acima de R$ 4.800.000,00 com a receita do ano dentro do limite (art. 22, § 5º)" do
      resultado = calcular(periodo: "2026-01", rbt12: 500_000_000, receita_mes: 10_000_000)
      assert_equal 6, resultado.faixa.numero
    end
  end
end
