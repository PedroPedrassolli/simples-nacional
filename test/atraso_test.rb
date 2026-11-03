# frozen_string_literal: true

require "test_helper"

# Multa e juros do DAS pago em atraso (Lei 9.430/1996, art. 61; Res. CGSN 140/2018, art. 40).
# Selic de data/selic.yml: maio de 2026 1,07% e junho 1,12%.
describe SimplesNacional::Atraso do
  let(:periodo) { Date.new(2026, 3, 1) }
  let(:pagamento) { Date.new(2026, 7, 15) }

  subject { SimplesNacional::Atraso.calcular(100_000, periodo, pagamento) }

  describe "vencimento" do
    def vencimento(mes) = SimplesNacional::Atraso.vencimento(SimplesNacional::Entrada.mes(mes))

    it "é o dia 20 do mês seguinte" do
      assert_equal Date.new(2026, 4, 20), vencimento("2026-03")
    end

    it "passa para o dia útil seguinte no fim de semana" do
      assert_equal Date.new(2026, 6, 22), vencimento("2026-05")
      assert_equal Date.new(2029, 1, 22), vencimento("2028-12")
    end

    it "passa para o dia útil seguinte no feriado de 20 de novembro (Lei 14.759/2023)" do
      assert_equal Date.new(2026, 11, 23), vencimento("2026-10")
    end

    # Carnaval (segunda e terça), Sexta-Feira Santa e Corpus Christi, a partir da Páscoa
    # (algoritmo de Meeus/Jones/Butcher), de 2026 a 2029. É uma conta de referência, copiada do
    # algoritmo como ele é publicado: quebrar em partes só para o RuboCop a deixaria mais difícil
    # de conferir.
    def moveis(ano) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
      a = ano % 19
      b, c = ano.divmod(100)
      d, e = b.divmod(4)
      g = (b - ((b + 8) / 25) + 1) / 3
      h = ((19 * a) + b - d - g + 15) % 30
      i, k = c.divmod(4)
      l = (32 + (2 * e) + (2 * i) - h - k) % 7
      m = (a + (11 * h) + (22 * l)) / 451
      mes, dia = (h + l - (7 * m) + 114).divmod(31)
      pascoa = Date.new(ano, mes, dia + 1)
      [pascoa - 48, pascoa - 47, pascoa - 2, pascoa + 60]
    end

    it "nunca cai num dia sem expediente bancário de data móvel de 2026 a 2029" do
      feriados = (2026..2029).flat_map { |ano| moveis(ano) }
      meses = (2026..2028).flat_map { |ano| (1..12).map { |numero| format("%<ano>d-%<mes>02d", ano:, mes: numero) } }
      assert_empty(meses.map { |mes| vencimento(mes) } & feriados)
      assert_includes moveis(2026), Date.new(2026, 4, 3) # a Sexta-Feira Santa de 2026, para conferir a conta
    end
  end

  describe "com dois meses de juros e mais de 60 dias de atraso" do
    it "limita a multa a 20%" do
      assert_equal [86, Rational(1, 5), 20_000], [subject.dias, subject.multa_percentual, subject.multa]
    end

    it "soma a Selic de maio e junho e 1% do mês do pagamento" do
      assert_equal %w[2026-05 2026-06], subject.meses_de_juros
      assert_equal [Rational(319, 10_000), 3_190], [subject.juros_percentual, subject.juros]
      assert_equal 123_190, subject.total
    end
  end

  describe "pago no mesmo mês do vencimento" do
    let(:pagamento) { Date.new(2026, 4, 25) }

    it "cobra 0,33% por dia de multa e não cobra juros" do
      assert_equal [5, 1_650, 0, 101_650], [subject.dias, subject.multa, subject.juros, subject.total]
    end
  end

  describe "pago até o vencimento" do
    let(:pagamento) { Date.new(2026, 4, 20) }

    it "não tem multa nem juros" do
      assert_equal [0, 0, 0, 100_000], [subject.dias, subject.multa, subject.juros, subject.total]
    end
  end

  describe "com mês de juros sem Selic publicada" do
    let(:periodo) { Date.new(2026, 10, 1) }
    let(:pagamento) { Date.new(2027, 1, 10) }

    it "deixa o mês de fora e diz qual é" do
      assert_equal ["2026-12"], subject.sem_selic
      assert_equal Rational(1, 100), subject.juros_percentual
      assert_equal Rational(99, 625), subject.multa_percentual
    end
  end

  describe "sem data de pagamento" do
    let(:pagamento) { nil }

    it "não calcula nada" do
      assert_nil subject
    end
  end

  describe ".conferir" do
    def conferir(texto) = SimplesNacional::Atraso.conferir(texto, Date.new(2026, 3, 1))

    it "aceita a data no formato AAAA-MM-DD" do
      assert_equal Date.new(2026, 4, 30), conferir("2026-04-30")
      assert_nil conferir(nil)
    end

    it "recusa data em outro formato ou que não existe" do
      erro = assert_raises(SimplesNacional::Entrada::EntradaInvalida) { conferir("30/04/2026") }
      assert_match(/AAAA-MM-DD/, erro.message)
      assert_raises(SimplesNacional::Entrada::EntradaInvalida) { conferir("2026-02-30") }
    end

    it "recusa pagamento antes do fim do mês de apuração ou mais de 10 anos depois" do
      assert_raises(SimplesNacional::Entrada::EntradaInvalida) { conferir("2026-03-31") }
      erro = assert_raises(SimplesNacional::Entrada::EntradaInvalida) { conferir("2037-01-01") }
      assert_match(/no máximo 10 anos/, erro.message)
    end
  end

  describe ".yaml_da_serie" do
    let(:json) { '[{"data":"01/01/2026","valor":"1.16"},{"data":"01/02/2026","valor":"1.00"}]' }

    it "monta o data/selic.yml com o cabeçalho, a data e os meses" do
      yaml = SimplesNacional::Atraso.yaml_da_serie(json, "2026-12-05")
      dados = YAML.safe_load(yaml)
      assert_equal({ "2026-01" => "1.16", "2026-02" => "1.00" }, dados["meses"])
      assert_equal "2026-12-05", dados["conferido_em"]
      assert yaml.start_with?("# Taxa Selic acumulada no mês")
    end

    it "recusa uma série que não é mensal" do
      assert_raises(ArgumentError) do
        SimplesNacional::Atraso.yaml_da_serie('[{"data":"15/01/2026","valor":"1.16"}]', "2026-12-05")
      end
    end
  end

  # Revenda de R$ 10.000,00 na 1ª faixa do Anexo I (4%): DAS de R$ 400,00.
  describe "no passo a passo" do
    def passo(periodo, pagamento)
      resultado = SimplesNacional.calcular(periodo:, rbt12: 10_000_000, pagamento:,
                                           atividades: [{ tipo: "revenda", receita: 1_000_000, opcoes: [] }])
      [resultado, resultado.passos.find { |item| item.titulo == "Multa e juros" }&.texto]
    end

    it "mostra a multa limitada, a Selic de dois meses e o total" do
      resultado, texto = passo("2026-03", "2026-07-15")
      assert_equal 49_276, resultado.atraso.total # 400,00 + 80,00 de multa + 3,19% de juros (12,76)
      assert_match(/Multa de mora: 0,33% × 86 = 20,00%, limitada a 20%, ou R\$ 80,00/, texto)
      assert_match(/Selic de maio de 2026 a junho de 2026 \(2,19%\) e 1% do mês do pagamento = 3,19%/, texto)
      assert_match(/Total a pagar: R\$ 400,00 \+ R\$ 80,00 \+ R\$ 12,76 = R\$ 492,76/, texto)
    end

    it "fala de um mês só de Selic" do
      _, texto = passo("2026-04", "2026-07-10")
      assert_match(/Selic de junho de 2026 \(1,12%\) e 1% do mês do pagamento = 2,12%/, texto)
    end

    it "cobra só 1% de juros no mês seguinte ao vencimento" do
      _, texto = passo("2026-03", "2026-05-04")
      assert_match(%r{Pago em 04/05/2026: 14 dias de atraso\. Multa de mora: 0,33% × 14 = 4,62%}, texto)
      assert_match(/Juros de mora: 1% do mês do pagamento = 1,00%, ou R\$ 4,00/, texto)
    end

    it "diz que não há juros no mesmo mês e um dia no singular" do
      _, texto = passo("2026-03", "2026-04-21")
      assert_match(/1 dia de atraso/, texto)
      assert_match(/Pago no mesmo mês do vencimento, não há juros de mora/, texto)
    end

    it "diz que não há multa nem juros até o vencimento" do
      _, texto = passo("2026-03", "2026-04-20")
      assert_equal "O DAS vence em 20/04/2026 (dia 20 do mês seguinte ou o dia útil depois). Pago até essa data, " \
                   "não há multa nem juros.", texto
    end

    it "avisa quais meses ainda não têm Selic" do
      resultado, = passo("2026-10", "2027-03-10")
      aviso = SimplesNacional::Avisos.montar(resultado).join
      assert_match(/A Selic de dezembro de 2026, janeiro de 2027 e fevereiro de 2027 ainda não foi publicada/, aviso)
      assert_match(/os juros de mora estão sem esses meses/, aviso)
    end
  end

  it "lê a Selic do data/selic.yml como fração" do
    assert_equal Rational(116, 10_000), SimplesNacional::Atraso.taxas.fetch("2026-01")
  end
end
