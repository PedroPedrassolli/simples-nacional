# frozen_string_literal: true

require "test_helper"
require_relative "../api/calcular"

# Testa a função da Vercel sem servidor: o request e o response são objetos simples com
# os mesmos métodos que o runtime usa. Valores fictícios.
describe "api/calcular.rb" do
  let(:query) { { "rbt12" => "500000.00", "receita_mes" => "40000.00", "anexo" => "3" } }
  let(:request) { Struct.new(:query).new(query) }
  let(:response) { Class.new(Hash) { attr_accessor :status, :body }.new }

  subject do
    Handler.call(request, response)
    JSON.parse(response.body)
  end

  describe "com um anexo informado" do
    it "devolve a alíquota efetiva e o DAS já formatados" do
      assert_equal ["9,9720%", "R$ 3.988,80", 398_880], subject.values_at("aliquota_efetiva", "das", "das_centavos")
      assert_equal 200, response.status
    end

    it "devolve o anexo, a faixa e os passos da conta" do
      assert_equal [3, 3, 4], [subject["anexo"], subject["faixa"], subject["passos"].size]
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

  describe "com o Fator R" do
    before { query.merge!("anexo" => "fator_r", "folha12" => "139999.99") }

    it "escolhe o anexo e mostra o Fator R sem arredondar para 28%" do
      assert_equal [5, "27,99%"], subject.values_at("anexo", "fator_r")
    end
  end

  describe "com centavos de uma casa" do
    # 40.000,50 × 9,972% = 3.988,84986... → R$ 3.988,85.
    before { query["receita_mes"] = "40000.5" }

    it "lê 0.5 como 50 centavos" do
      assert_equal 398_885, subject["das_centavos"]
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

    it "recusa número grande demais antes de calcular" do
      assert_match(/como número/, erro("rbt12" => "12345678.00"))
    end

    it "repassa a mensagem da biblioteca para valor zero" do
      assert_match(/precisa ser maior que zero/, erro("rbt12" => "0"))
    end

    it "repassa a mensagem da biblioteca para valor acima do limite" do
      assert_match(/passa de R\$ 4\.800\.000,00/, erro("rbt12" => "4800000.01"))
    end

    it "pede a folha no Fator R" do
      assert_match(/informe a folha de salários/, erro("anexo" => "fator_r"))
    end

    it "recusa folha em formato errado no Fator R" do
      assert_match(/a folha de salários dos 12 meses anteriores como número/,
                   erro("anexo" => "fator_r", "folha12" => "-1"))
    end
  end
end
