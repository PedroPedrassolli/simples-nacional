# frozen_string_literal: true

# Apuração do Simples Nacional (Lei Complementar nº 123/2006), em Ruby puro e sem
# dependências: a mesma conta do PGDAS-D, receita por receita, para conferir e preencher a
# declaração. As tabelas dos Anexos I a V ficam em data/anexos/<ano>/, cada uma com o link
# da fonte oficial e a data de vigência.
#
# É uma estimativa: a guia oficial continua saindo do PGDAS-D.
module SimplesNacional
  # Atalho para o cálculo completo (ver SimplesNacional::Calculo).
  def self.calcular(...) = Calculo.calcular(...)

  # O DAS do MEI (ver SimplesNacional::Mei).
  def self.calcular_mei(...) = Mei.calcular(...)
end

require_relative "simples_nacional/regras"
require_relative "simples_nacional/tabelas"
require_relative "simples_nacional/formato"
require_relative "simples_nacional/atividades"
require_relative "simples_nacional/atividades_informadas"
require_relative "simples_nacional/historico"
require_relative "simples_nacional/inicio_de_atividade"
require_relative "simples_nacional/entrada"
require_relative "simples_nacional/acumulados"
require_relative "simples_nacional/fora_do_das"
require_relative "simples_nacional/fora_do_das_estimativas"
require_relative "simples_nacional/fora_do_das_do_icms"
require_relative "simples_nacional/valores_fixos"
require_relative "simples_nacional/sublimite"
require_relative "simples_nacional/limite"
require_relative "simples_nacional/limite_da_exportacao"
require_relative "simples_nacional/atraso"
require_relative "simples_nacional/reparticao"
require_relative "simples_nacional/fator_r"
require_relative "simples_nacional/apuracao_da_atividade"
require_relative "simples_nacional/passos"
require_relative "simples_nacional/passos_da_atividade"
require_relative "simples_nacional/passo_da_faixa"
require_relative "simples_nacional/passo_da_divisao"
require_relative "simples_nacional/passo_dos_ajustes"
require_relative "simples_nacional/passo_do_sublimite"
require_relative "simples_nacional/passo_do_limite"
require_relative "simples_nacional/passos_do_atraso"
require_relative "simples_nacional/passos_do_fim"
require_relative "simples_nacional/avisos"
require_relative "simples_nacional/calculo"
require_relative "simples_nacional/mei"
require_relative "simples_nacional/passos_do_mei"
