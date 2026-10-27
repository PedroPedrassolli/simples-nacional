# frozen_string_literal: true

# A cobertura precisa começar antes de carregar a biblioteca, senão o SimpleCov não
# vê as linhas que rodam no require.
require "simplecov"
SimpleCov.start do
  add_filter "/test/"
  # Toda linha de lib/ e api/ precisa ser executada por algum teste.
  minimum_coverage 100
end

require "minitest/autorun"
require "simples_nacional"

# Cada arquivo de api/ define um Handler no topo (é o que a Vercel procura). Para dois
# deles conviverem nos testes, cada um é carregado dentro de um módulo próprio:
#   API = carregar_api("calcular")  →  API::Handler, API::CalcularApi
# Cada arquivo é carregado uma vez só: carregar de novo zera a cobertura dele.
def carregar_api(nome)
  @apis ||= {}
  @apis[nome] ||= Module.new.tap { |modulo| load File.expand_path("../api/#{nome}.rb", __dir__), modulo }
end
