# frozen_string_literal: true

require "test_helper"

CNPJ_API = carregar_api("cnpj")

# Nenhum teste chama a internet: a consulta da br_validators usa um cliente falso, que
# devolve [status, corpo] como a BrasilAPI. CNPJs e empresas fictícios.
describe "api/cnpj.rb" do
  let(:cnpj) { "11.222.333/0001-81" }
  let(:brasilapi) do
    {
      "razao_social" => "EMPRESA FICTICIA LTDA", "descricao_situacao_cadastral" => "ATIVA",
      "cnae_fiscal" => 6_201_501, "cnae_fiscal_descricao" => "Desenvolvimento de programas de computador sob encomenda",
      "opcao_pelo_simples" => true, "data_opcao_pelo_simples" => "2020-01-01", "data_exclusao_do_simples" => nil,
      "qsa" => [{ "nome_socio" => "PESSOA FICTICIA" }]
    }
  end
  let(:status_da_brasilapi) { 200 }
  let(:chamadas) { [] }
  let(:request) { Struct.new(:query).new({ "cnpj" => cnpj }) }
  let(:response) { Class.new(Hash) { attr_accessor :status, :body }.new }

  # O cliente falso responde na hora da chamada, com o status e os dados do teste.
  before do
    teste = self
    BrValidators::Consulta.cliente = Object.new.tap do |falso|
      falso.define_singleton_method(:get) { |uri| teste.responder_brasilapi(uri) }
    end
  end

  def responder_brasilapi(uri)
    chamadas << uri.to_s
    [status_da_brasilapi, JSON.generate(brasilapi)]
  end

  # Volta para o cliente de verdade, para não afetar outros testes.
  after { BrValidators::Consulta.cliente = nil }

  subject do
    CNPJ_API::Handler.call(request, response)
    JSON.parse(response.body)
  end

  it "devolve a empresa, o CNAE formatado e a opção pelo Simples" do
    assert_equal ["EMPRESA FICTICIA LTDA", "6201-5/01", true, "01/01/2020"],
                 [subject["razao_social"], subject.dig("cnae", "codigo"), subject.dig("simples", "optante"),
                  subject.dig("simples", "desde")]
  end

  # Os testes da página (web/e2e) simulam esta API com web/e2e/fixtures/cnpj.json.
  it "devolve o mesmo que a fixture dos testes da página" do
    guardado = JSON.parse(File.read(File.expand_path("../web/e2e/fixtures/cnpj.json", __dir__)))
    assert_equal guardado, subject
  end

  it "não devolve o quadro de sócios" do
    refute_includes response.body.to_s + subject.to_s, "PESSOA FICTICIA"
  end

  it "consulta o CNPJ só com os números e pede cache de um dia" do
    subject
    assert_equal ["https://brasilapi.com.br/api/cnpj/v1/11222333000181"], chamadas
    assert_equal "public, max-age=0, s-maxage=86400", response["Cache-Control"]
  end

  describe "quando a empresa não é optante" do
    before { brasilapi.merge!("opcao_pelo_simples" => false, "data_exclusao_do_simples" => "2023-12-31") }

    it "diz que não é optante e mostra a data de exclusão" do
      assert_equal({ "optante" => false, "desde" => "01/01/2020", "excluida_em" => "31/12/2023" }, subject["simples"])
    end
  end

  describe "sem CNAE na resposta" do
    before { brasilapi.delete("cnae_fiscal") }

    it "devolve o código como nulo" do
      assert_nil subject.dig("cnae", "codigo")
    end
  end

  describe "com CNPJ inválido" do
    let(:cnpj) { "11.222.333/0001-80" }

    it "responde 400 sem chamar a internet" do
      assert_equal "CNPJ inválido: confira os números.", subject["erro"]
      assert_equal [400, []], [response.status, chamadas]
    end
  end

  describe "com CNPJ que a BrasilAPI não conhece" do
    let(:status_da_brasilapi) { 404 }

    it "responde 404 sem cache" do
      assert_match(/não foi encontrado/, subject["erro"])
      assert_equal [404, nil], [response.status, response["Cache-Control"]]
    end
  end

  describe "com a BrasilAPI fora do ar" do
    let(:status_da_brasilapi) { 503 }

    it "responde 502 com mensagem para tentar de novo" do
      assert_match(/Tente de novo/, subject["erro"])
      assert_equal 502, response.status
    end
  end
end
