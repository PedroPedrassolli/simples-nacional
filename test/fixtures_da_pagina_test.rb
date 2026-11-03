# frozen_string_literal: true

require "test_helper"
require "json"

API_DA_PAGINA = carregar_api("calcular")

# Os testes da página (web/e2e) simulam a API com respostas guardadas em
# web/e2e/fixtures/. Este teste garante que elas são iguais ao que a API devolve hoje:
# se o JSON mudar, a CI avisa. Para atualizar as fixtures depois de mudar a API de
# propósito: ATUALIZAR_FIXTURES=1 bundle exec rake test (e confira o diff).
# Os parâmetros são os que a página manda (web/src/formulario.js). Valores fictícios.
FIXTURES_DA_PAGINA = {
  "anexo-3.json" => { "periodo" => "2026-03", "atividades" => "servicos_3:40000.00", "rbt12" => "500000.00" },
  "fator-r.json" => { "periodo" => "2026-03", "atividades" => "fator_r:40000.00", "rbt12" => "500000.00",
                      "folha12" => "139999.99" },
  "varias-receitas.json" => { "periodo" => "2026-03", "atividades" => "revenda:30000.00:st_icms;servicos_3:10000.00",
                              "rbt12" => "500000.00" },
  "anexo-4.json" => { "periodo" => "2026-03", "atividades" => "servicos_4:40000.00", "rbt12" => "500000.00",
                      "folha_empregados" => "30000.00", "pro_labore" => "5000.00", "rat" => "2", "fap" => "1.5" },
  "ano-2027.json" => { "periodo" => "2027-03", "atividades" => "servicos_3:40000.00", "rbt12" => "500000.00",
                       "receita_mes_anterior" => "40000.00", "ibs_cbs_fora" => "1", "aliquota_cbs" => "8.8",
                       "creditos_cbs" => "1000.00" },
  "sublimite.json" => { "periodo" => "2026-10", "atividades" => "revenda:400000.00", "rbt12" => "3900000.00",
                        "receita_ano" => "3300000.00", "receita_ano_anterior" => "3700000.00",
                        "aliquota_icms" => "18", "creditos_icms" => "20000.00" }
}.freeze

describe "fixtures dos testes da página" do
  subject { API_DA_PAGINA::CalcularApi }

  FIXTURES_DA_PAGINA.each do |arquivo, parametros|
    it "#{arquivo} é a resposta atual da API" do
      status, corpo = subject.responder(parametros)
      caminho = File.expand_path("../web/e2e/fixtures/#{arquivo}", __dir__)
      File.write(caminho, "#{JSON.pretty_generate(corpo)}\n") if ENV["ATUALIZAR_FIXTURES"]
      assert_equal 200, status
      assert_equal JSON.parse(File.read(caminho, encoding: "UTF-8")), JSON.parse(JSON.generate(corpo))
    end
  end
end
