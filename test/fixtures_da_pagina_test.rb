# frozen_string_literal: true

require "test_helper"
require "json"
require_relative "../api/calcular"

# Os testes da página (web/e2e) simulam a API com respostas guardadas em
# web/e2e/fixtures/. Este teste garante que elas são iguais ao que a API devolve hoje:
# se o JSON mudar, a CI avisa para atualizar as fixtures.
describe "fixtures dos testes da página" do
  subject { CalcularApi }

  {
    "anexo-3.json" => { "rbt12" => "500000.00", "receita_mes" => "40000.00", "anexo" => "3" },
    "fator-r.json" => { "rbt12" => "500000.00", "receita_mes" => "40000.00", "anexo" => "fator_r",
                        "folha12" => "139999.99" }
  }.each do |arquivo, parametros|
    it "#{arquivo} é a resposta atual da API" do
      _status, corpo = subject.responder(parametros)
      guardado = JSON.parse(File.read(File.expand_path("../web/e2e/fixtures/#{arquivo}", __dir__)))
      assert_equal guardado, JSON.parse(JSON.generate(corpo))
    end
  end
end
