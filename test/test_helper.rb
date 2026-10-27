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
