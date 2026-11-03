# frozen_string_literal: true

require "test_helper"

CALCULAR = carregar_api("calcular")

# Testa a função da Vercel sem servidor: o request e o response são objetos simples com
# os mesmos métodos que o runtime usa. Valores fictícios.
describe "api/calcular.rb" do
  let(:query) { { "periodo" => "2026-03", "rbt12" => "500000.00", "receita_mes" => "40000.00", "anexo" => "3" } }
  let(:request) { Struct.new(:query).new(query) }
  let(:response) { Class.new(Hash) { attr_accessor :status, :body }.new }

  subject do
    CALCULAR::Handler.call(request, response)
    JSON.parse(response.body)
  end

  describe "com um anexo informado" do
    it "devolve a alíquota efetiva e o DAS já formatados" do
      assert_equal ["9,9720%", "R$ 3.988,80", 398_880], subject.values_at("aliquota_efetiva", "das", "das_centavos")
      assert_equal 200, response.status
    end

    it "devolve o anexo, a faixa e os passos da conta" do
      assert_equal [3, 3, 5], [subject["anexo"], subject["faixa"], subject["passos"].size]
    end

    it "devolve a divisão do DAS entre os tributos" do
      iss = { "nome" => "ISS", "percentual" => "3,2409%", "valor" => "R$ 1.296,36", "valor_centavos" => 129_636 }
      assert_equal iss, subject["tributos"].last
      nomes = subject["tributos"].map { |tributo| tributo["nome"] }
      assert_equal %w[IRPJ CSLL Cofins PIS/Pasep CPP ISS], nomes
    end

    it "devolve a fonte e a vigência da tabela" do
      assert_equal "https://www.planalto.gov.br/ccivil_03/leis/lcp/lcp123.htm", subject.dig("tabela", "fonte")
      assert_equal "2018-01-01", subject.dig("tabela", "vigencia")
    end

    it "pede cache de um dia na Vercel" do
      subject
      assert_equal "public, max-age=0, s-maxage=86400", response["Cache-Control"]
    end

    it "não usa a folha" do
      query["folha12"] = "qualquer coisa"
      assert_nil subject["fator_r"]
    end
  end

  describe "com início de atividade no próprio mês" do
    # RBT12 = 20.000 × 12 = 240.000 → Anexo I, 2ª faixa: (240.000 × 7,3% − 5.940) ÷ 240.000 = 4,825%.
    before { query.merge!("inicio" => "2026-03", "rbt12" => "", "receita_mes" => "20000.00", "anexo" => "1") }

    it "calcula sem a receita anterior e devolve o mês e a RBT12 usada" do
      assert_equal ["março de 2026", "R$ 240.000,00", "R$ 965,00"], subject.values_at("periodo_nome", "rbt12", "das")
      assert_equal "2026-03", subject["periodo"]
    end
  end

  describe "com o Fator R" do
    before { query.merge!("anexo" => "fator_r", "folha12" => "139999.99") }

    it "escolhe o anexo e mostra o Fator R sem arredondar para 28%" do
      assert_equal [5, "27,99%"], subject.values_at("anexo", "fator_r")
    end
  end

  describe "com várias receitas" do
    before do
      query.delete("anexo")
      query.delete("receita_mes")
      query["atividades"] = "revenda:30000.00:st_icms;servicos_3:10000.00"
    end

    # Ver test/segregacao_test.rb: 1.342,24 + 997,20 = 2.339,44.
    it "calcula cada receita e devolve a lista" do
      assert_equal [233_944, 2], [subject["das_centavos"], subject["atividades"].size]
      primeira = subject["atividades"].first
      assert_equal ["revenda", ["ICMS já pago por substituição tributária ou antecipação"], 1, "4,4741%"],
                   primeira.values_at("tipo", "opcoes", "anexo", "percentual")
    end

    it "recusa valor em formato errado numa das receitas" do
      query["atividades"] = "revenda:30.000,00"
      assert_match(/como número, por exemplo 500000.00/, subject["erro"])
    end
  end

  describe "com o mês a mês" do
    before do
      query.delete("rbt12")
      (1..12).each { |n| query[Date.new(2025, 2, 1).next_month(n).strftime("mes_%Y-%m")] = "41666.66:0:5000" }
    end

    it "soma os meses" do
      assert_equal "R$ 499.999,92", subject["rbt12"]
    end

    it "recusa mês em formato errado" do
      query["mes_2026-02"] = "abc"
      assert_match(/No mês a mês, informe 2026-02 como número/, subject["erro"])
    end

    it "recusa mês com bytes inválidos sem quebrar (ex.: %FF%FE na URL)" do
      query["mes_2026-02"] = "\xFF\xFE"
      assert_match(/No mês a mês, informe 2026-02 como número/, subject["erro"])
      assert_equal 400, response.status
    end
  end

  describe "com o que fica fora do DAS" do
    before do
      query.merge!("anexo" => "4", "folha_empregados" => "30000.00", "pro_labore" => "5000", "rat" => "2",
                   "fap" => "1.5", "aliquota_iss" => "3.5")
    end

    it "devolve a estimativa da CPP e o total estimado" do
      cpp = subject["fora_do_das"].first
      assert_equal ["CPP", "R$ 7.900,00"], cpp.values_at("tributo", "valor")
      assert_equal subject["das_centavos"] + 790_000, subject["total_estimado_centavos"]
    end

    it "recusa RAT fora de 1 a 3" do
      query["rat"] = "4"
      assert_match(/O RAT precisa ser 1, 2 ou 3/, subject["erro"])
    end

    it "recusa FAP em formato errado" do
      query["fap"] = "1,5"
      assert_match(/FAP como número/, subject["erro"])
    end

    it "recusa alíquota em formato errado" do
      query["aliquota_iss"] = "3,5%"
      assert_match(/aliquota iss em %/, subject["erro"])
    end
  end

  describe "com o IBS e a CBS fora do DAS em 2027" do
    before { query.merge!("periodo" => "2027-01", "ibs_cbs_fora" => "1", "aliquota_cbs" => "8.8") }

    it "tira a CBS e o IBS e estima a CBS" do
      assert_equal(%w[IRPJ CSLL CPP ISS], subject["tributos"].map { |tributo| tributo["nome"] })
      cbs = subject["fora_do_das"].find { |estimativa| estimativa["tributo"] == "CBS" }
      assert_equal "R$ 3.520,00", cbs["valor"]
    end
  end

  describe "com centavos de uma casa" do
    # 40.000,50 × 9,972% = 3.988,84986... → R$ 3.988,85.
    before { query["receita_mes"] = "40000.5" }

    it "lê 0.5 como 50 centavos" do
      assert_equal 398_885, subject["das_centavos"]
    end
  end

  describe "com pagamento em atraso" do
    # R$ 3.988,80 vencido em 20/04/2026 e pago em 15/07/2026: multa de 20% (R$ 797,76) e juros de
    # 3,19% (Selic de maio e junho e 1% de julho: R$ 127,24).
    before { query["pagamento"] = "2026-07-15" }

    it "devolve a multa, os juros e o total" do
      atraso = subject["atraso"]
      assert_equal ["20/04/2026", 86, "20,00%", "R$ 797,76"],
                   atraso.values_at("vencimento", "dias", "multa_percentual", "multa")
      assert_equal ["3,19%", "R$ 127,24", 491_380], atraso.values_at("juros_percentual", "juros", "total_centavos")
    end

    it "não devolve atraso sem a data" do
      query.delete("pagamento")
      assert_nil subject["atraso"]
    end

    it "recusa data em outro formato" do
      query["pagamento"] = "15/07/2026"
      assert_match(/AAAA-MM-DD/, subject["erro"])
    end
  end

  describe "com valores fixos, isenção e redução" do
    before do
      query.merge!("rbt12" => "200000.00", "receita_ano_anterior" => "150000.00", "iss_fixo" => "400.00",
                   "atividades" => "servicos_3:20000.00;industria_iss:40000.00:reducao_iss=40")
    end

    it "soma o valor fixo e mostra a redução com o percentual" do
      assert_includes subject["tributos"].map { |tributo| tributo["nome"] }, "ISS (valor fixo)"
      assert_equal ["Redução do ISS dada pelo município (40,00%)"], subject["atividades"].last["opcoes"]
    end

    it "recusa valor fixo em formato errado" do
      query["icms_fixo"] = "abc"
      assert_match(/como número/, subject["erro"])
    end
  end

  describe "com ICMS-ST e DIFAL" do
    before do
      query.merge!("st_valor" => "100.00", "st_mva" => "40", "st_aliquota_interna" => "18",
                   "st_aliquota_propria" => "12", "difal_valor" => "100.00", "difal_aliquota_interna" => "17.5",
                   "difal_aliquota_interestadual" => "12")
    end

    it "estima os dois fora do DAS" do
      valores = subject["fora_do_das"].to_h { |estimativa| [estimativa["tributo"], estimativa["valor"]] }
      assert_equal({ "ICMS-ST" => "R$ 13,20", "DIFAL" => "R$ 5,50" }, valores.slice("ICMS-ST", "DIFAL"))
    end
  end

  describe "com exportação acima do limite extra" do
    before do
      query.merge!("periodo" => "2026-10", "rbt12" => "1000000.00", "rbt12_exportacao" => "4700000.00",
                   "receita_ano_exportacao" => "4700000.00", "atividades" => "revenda:200000.00:exportacao")
    end

    it "cobra a parte acima do limite e avisa da exclusão" do
      assert_equal 1_448_609, subject["das_centavos"]
      assert(subject["avisos"].any? { |aviso| aviso.include?("limite extra de R$ 4.800.000,00") })
    end
  end

  describe "com o MEI" do
    let(:query) { { "regime" => "mei", "periodo" => "2026-03", "mei_atividade" => "comercio" } }

    it "devolve o DAS fixo e os tributos" do
      assert_equal ["mei", "R$ 82,05", 8_205], subject.values_at("regime", "das", "das_centavos")
      assert_equal([["INSS", "R$ 81,05"], ["ICMS", "R$ 1,00"]],
                   subject["tributos"].map { |tributo| tributo.values_at("nome", "valor") })
    end

    it "devolve o limite com a diferença do excesso" do
      query["receita_ano"] = "90000.00"
      limite = subject["limite"]
      assert_equal ["R$ 81.000,00", "R$ 9.000,00", "R$ 360,00", "ate_vinte_por_cento"],
                   limite.values_at("limite", "excesso", "diferenca", "situacao")
    end

    it "devolve o atraso e os passos" do
      query.merge!("pagamento" => "2026-04-21", "transportador" => "1")
      assert_equal [1, "0,33%"], subject["atraso"].values_at("dias", "multa_percentual")
      assert(subject["passos"].any? { |passo| passo["titulo"] == "Multa e juros" })
    end

    it "pede a atividade" do
      query["mei_atividade"] = "outra"
      assert_equal "Escolha a atividade do MEI.", subject["erro"]
    end
  end

  describe "com parâmetros inválidos" do
    def erro(mudancas)
      query.merge!(mudancas)
      subject["erro"]
    end

    it "recusa o formato brasileiro (a página converte antes)" do
      assert_match(/RBT12\) como número, por exemplo 500000.00/, erro("rbt12" => "500.000,00"))
      assert_equal 400, response.status
    end

    it "não pede cache para resposta com erro" do
      erro("anexo" => "9")
      assert_nil response["Cache-Control"]
    end

    it "recusa parâmetro que falta" do
      query.delete("receita_mes")
      assert_match(/a receita do mês como número/, subject["erro"])
    end

    it "recusa anexo que não existe" do
      assert_equal "Escolha o anexo: 1, 2, 3, 4, 5 ou fator_r.", erro("anexo" => "6")
    end

    it "recusa texto com bytes inválidos sem quebrar (ex.: %FF%FE na URL)" do
      assert_match(/RBT12\) como número/, erro("rbt12" => "\xFF\xFE"))
      assert_equal 400, response.status
    end

    it "recusa número grande demais antes de calcular" do
      assert_match(/como número/, erro("rbt12" => "12345678.00"))
    end

    it "repassa a mensagem da biblioteca para valor zero" do
      assert_match(/A receita do mês precisa ser maior que zero/, erro("receita_mes" => "0"))
    end

    it "pede o mês de apuração" do
      assert_match(/mês de apuração no formato AAAA-MM/, erro("periodo" => " "))
    end

    it "recusa mês de 2029" do
      assert_match(/regras de 2026 a 2028/, erro("periodo" => "2029-01"))
    end

    it "repassa a mensagem da biblioteca quando a receita do mês pode passar do sublimite" do
      assert_match(/Informe a receita bruta de 2026 até o mês anterior/, erro("receita_mes" => "4800000.01"))
    end

    it "pede a folha no Fator R" do
      assert_match(/informe a folha de salários/, erro("anexo" => "fator_r"))
    end

    it "recusa folha em formato errado no Fator R" do
      assert_match(/a folha de salários como número/,
                   erro("anexo" => "fator_r", "folha12" => "-1"))
    end
  end
end
