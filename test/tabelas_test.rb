# frozen_string_literal: true

require "test_helper"
require "tmpdir"

describe SimplesNacional::Tabelas do
  subject { SimplesNacional::Tabelas }

  # Um anexo válido no formato do YAML, para montar arquivos de teste.
  let(:reparticao) { { "IRPJ" => "60.00", "ICMS" => "40.00" } }
  let(:faixas) do
    lista = %w[180000.00 360000.00 720000.00 1800000.00 3600000.00 4800000.00].map do |ate|
      # dup: o mesmo Hash repetido vira um alias no YAML, que o safe_load recusa.
      { "ate" => ate, "aliquota" => "4.00", "deduzir" => "0.00", "reparticao" => reparticao.dup }
    end
    # Na 6ª faixa não entra ICMS nem ISS.
    lista.last["reparticao"] = { "IRPJ" => "100.00" }
    lista
  end
  let(:dados) do
    { "anexo" => 1, "nome" => "Teste", "fonte" => "https://www.planalto.gov.br/ccivil_03/leis/lcp/lcp123.htm",
      "redacao" => "Lei Complementar nº 155/2016", "vigencia" => "2018-01-01", "conferido_em" => "2026-10-27",
      "faixas" => faixas }
  end

  # Grava o conteúdo num YAML temporário e lê com a biblioteca.
  def ler(conteudo)
    Dir.mktmpdir do |pasta|
      arquivo = File.join(pasta, "anexo-teste.yml")
      File.write(arquivo, conteudo.is_a?(String) ? conteudo : YAML.dump(conteudo))
      subject.ler(arquivo)
    end
  end

  def erro(conteudo)
    assert_raises(SimplesNacional::Tabelas::TabelaInvalida) { ler(conteudo) }.message
  end

  # Alíquota efetiva (art. 18, § 1º-A): (RBT12 × alíquota nominal − parcela a deduzir) ÷ RBT12.
  def efetiva(faixa, rbt12) = ((rbt12 * faixa.aliquota) - faixa.deduzir) / rbt12

  describe ".todas, com as tabelas do repositório" do
    let(:anexos) { subject.todas }

    it "tem os Anexos I a V" do
      assert_equal [1, 2, 3, 4, 5], anexos.keys
    end

    it "traz a fonte oficial e a vigência em todos os anexos" do
      anexos.each_value do |anexo|
        assert_equal "https://www.planalto.gov.br/ccivil_03/leis/lcp/lcp123.htm", anexo.fonte
        assert_equal Date.new(2018, 1, 1), anexo.vigencia
      end
    end

    it "termina a última faixa no limite da empresa de pequeno porte (art. 3º, II)" do
      anexos.each_value { |anexo| assert_equal 4_800_000, anexo.faixas.last.ate }
    end

    it "começa a primeira faixa sem parcela a deduzir" do
      anexos.each_value { |anexo| assert_equal 0, anexo.faixas.first.deduzir }
    end

    # Conferência da digitação que não depende de copiar a tabela de novo: nas bordas
    # entre as faixas 1 a 5, a parcela a deduzir faz a alíquota efetiva ser a mesma dos
    # dois lados. Da 5ª para a 6ª faixa a própria lei não segue essa regra.
    it "não deixa a alíquota efetiva saltar nas bordas entre as faixas 1 a 5" do
      anexos.each_value do |anexo|
        anexo.faixas.first(5).each_cons(2) do |faixa, proxima|
          assert_equal efetiva(faixa, faixa.ate), efetiva(proxima, faixa.ate),
                       "Anexo #{anexo.numero}, borda da faixa #{faixa.numero} para a #{proxima.numero}"
        end
      end
    end

    it "guarda a alíquota como fração exata, já dividida por 100" do
      # Anexo I, 2ª faixa: 7,30%.
      assert_equal Rational(73, 1000), anexos[1].faixas[1].aliquota
    end

    it "guarda a repartição dos tributos de cada faixa, somando 100%" do
      # Anexo I, 1ª faixa: ICMS de 34,00%.
      assert_equal Rational(34, 100), anexos[1].faixas.first.reparticao["ICMS"]
      anexos.each_value do |anexo|
        anexo.faixas.each { |faixa| assert_equal 1, faixa.reparticao.values.sum, "Anexo #{anexo.numero}" }
      end
    end

    it "tem a repartição da nota do ISS só na 5ª faixa dos Anexos III e IV" do
      com_nota = anexos.values.flat_map { |anexo| anexo.faixas.select(&:teto_iss).map { [anexo.numero, _1.numero] } }
      assert_equal [[3, 5], [4, 5]], com_nota
      assert_equal Rational(602, 10_000), anexos[3].faixas[4].teto_iss["IRPJ"]
    end
  end

  describe ".ler, com um arquivo de teste" do
    it "lê um arquivo válido" do
      assert_equal [1, 2, 3, 4, 5, 6], ler(dados).faixas.map(&:numero)
    end

    it "recusa arquivo sem fonte" do
      assert_match(/anexo-teste\.yml: falta fonte/, erro(dados.except("fonte")))
    end

    it "recusa arquivo sem vigência" do
      assert_match(/falta vigencia/, erro(dados.merge("vigencia" => " ")))
    end

    it "recusa fonte que não é um link https" do
      assert_match(/link https/, erro(dados.merge("fonte" => "http://www.planalto.gov.br")))
    end

    it "recusa vigência que não é uma data" do
      assert_match(/precisam ser datas/, erro(dados.merge("vigencia" => "2018-13-01")))
    end

    it "recusa data sem aspas" do
      assert_match(/entre aspas/, erro(YAML.dump(dados).sub(/["']2018-01-01["']/, "2018-01-01")))
    end

    it "recusa anexo fora de 1 a 5" do
      assert_match(/de 1 a 5/, erro(dados.merge("anexo" => 6)))
    end

    it "recusa tabela sem as 6 faixas" do
      assert_match(/6 faixas/, erro(dados.merge("faixas" => faixas.first(5))))
    end

    it "recusa número com vírgula" do
      faixas[1]["aliquota"] = "7,30"
      assert_match(/5940\.00/, erro(dados))
    end

    it "recusa faixas fora de ordem" do
      assert_match(/ordem crescente/, erro(dados.merge("faixas" => faixas.reverse)))
    end

    it "recusa repartição que não soma 100%" do
      faixas[0]["reparticao"] = { "IRPJ" => "60.00", "ICMS" => "39.99" }
      assert_match(/somar 100\.00/, erro(dados))
    end

    it "recusa nota do ISS que não soma 100%" do
      faixas[4]["teto_iss"] = { "IRPJ" => "99.00" }
      assert_match(/somar 100\.00/, erro(dados))
    end

    it "recusa ICMS ou ISS na 6ª faixa" do
      faixas[5]["reparticao"] = reparticao.dup
      assert_match(/6ª faixa não pode ter ICMS nem ISS/, erro(dados))
    end

    it "recusa faixa sem repartição" do
      faixas[2].delete("reparticao")
      assert_match(/6 faixas/, erro(dados))
    end

    it "recusa percentual de repartição com vírgula" do
      faixas[1]["reparticao"] = { "IRPJ" => "60,00", "ICMS" => "40.00" }
      assert_match(/5940\.00/, erro(dados))
    end

    it "recusa arquivo que não é um mapa" do
      assert_match(/não é um mapa/, erro("- 1\n- 2\n"))
    end
  end
end
