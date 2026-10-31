# frozen_string_literal: true

# Cálculo do Simples Nacional (Lei Complementar nº 123/2006), em Ruby puro e sem
# dependências. As tabelas dos Anexos I a V ficam em data/anexos/, cada uma com o
# link da fonte oficial e a data de vigência.
#
# É uma estimativa educativa: não substitui o PGDAS-D nem um contador.
module SimplesNacional
  # Atalho para o cálculo completo (ver SimplesNacional::Calculo).
  def self.calcular(...) = Calculo.calcular(...)
end

require_relative "simples_nacional/tabelas"
require_relative "simples_nacional/formato"
require_relative "simples_nacional/entrada"
require_relative "simples_nacional/inicio_de_atividade"
require_relative "simples_nacional/sublimite"
require_relative "simples_nacional/passos"
require_relative "simples_nacional/passo_da_divisao"
require_relative "simples_nacional/passo_do_sublimite"
require_relative "simples_nacional/fator_r"
require_relative "simples_nacional/reparticao"
require_relative "simples_nacional/calculo"
