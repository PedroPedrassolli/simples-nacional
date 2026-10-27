# frozen_string_literal: true

require "json"
require_relative "../lib/simples_nacional"

# Função da Vercel que a página chama. Toda a regra fica na biblioteca (lib/); aqui só
# se lê a URL, confere o formato dos números e monta o JSON.
#
#   GET /api/calcular?rbt12=500000.00&receita_mes=40000.00&anexo=3
#   GET /api/calcular?rbt12=500000.00&receita_mes=40000.00&anexo=fator_r&folha12=150000.00
#
# Os valores vão em reais, com ponto e até duas casas ("500000.00"); a página converte o
# que a pessoa digitou ("500.000,00") antes de chamar. anexo: 1 a 5 ou fator_r.
module CalcularApi
  # Até R$ 9.999.999,99: cobre o limite do Simples e recusa textos enormes logo de cara.
  VALOR = /\A(\d{1,7})(?:\.(\d{1,2}))?\z/

  ANEXOS = { "1" => 1, "2" => 2, "3" => 3, "4" => 4, "5" => 5, "fator_r" => :fator_r }.freeze

  NOMES = {
    "rbt12" => "a receita bruta dos 12 meses anteriores (RBT12)",
    "receita_mes" => "a receita do mês",
    "folha12" => "a folha de salários dos 12 meses anteriores"
  }.freeze

  # Parâmetro com problema: vira resposta 400 com a mensagem.
  class ParametroInvalido < StandardError; end

  # Devolve [status HTTP, corpo da resposta].
  def self.responder(parametros)
    anexo = ANEXOS[parametros["anexo"].to_s] || raise(ParametroInvalido, "Escolha o anexo: 1, 2, 3, 4, 5 ou fator_r.")
    folha12 = anexo == :fator_r && parametros["folha12"] ? centavos(parametros, "folha12") : nil
    resultado = SimplesNacional.calcular(rbt12: centavos(parametros, "rbt12"),
                                         receita_mes: centavos(parametros, "receita_mes"),
                                         anexo: anexo, folha12: folha12)
    [200, corpo(resultado)]
  rescue ParametroInvalido, SimplesNacional::Calculo::EntradaInvalida => e
    [400, { erro: e.message }]
  end

  # "500000.5" → 50_000_050 centavos.
  def self.centavos(parametros, nome)
    # scrub troca bytes que não são UTF-8 válido por "�". Sem ele, um texto quebrado
    # (ex.: %FF na URL) levanta ArgumentError no match e vira erro 500 em vez de 400.
    reais, decimais = VALOR.match(parametros[nome].to_s.scrub)&.captures
    raise ParametroInvalido, "Informe #{NOMES[nome]} como número, por exemplo 500000.00." unless reais

    (reais.to_i * 100) + decimais.to_s.ljust(2, "0").to_i
  end

  def self.corpo(resultado)
    anexo = resultado.anexo
    { anexo: anexo.numero, anexo_nome: anexo.nome, faixa: resultado.faixa.numero }
      .merge(valores(resultado))
      .merge(tributos: tributos(resultado.tributos), passos: resultado.passos.map(&:to_h),
             tabela: { fonte: anexo.fonte, redacao: anexo.redacao, vigencia: anexo.vigencia.iso8601 })
  end

  # A divisão do DAS: percentual sobre a receita do mês e valor de cada tributo.
  def self.tributos(lista)
    lista.map do |tributo|
      { nome: tributo.nome, percentual: SimplesNacional::Formato.percentual(tributo.percentual, 4),
        valor: SimplesNacional::Formato.reais(tributo.valor), valor_centavos: tributo.valor }
    end
  end

  # Percentuais e dinheiro já no formato brasileiro, para a página só mostrar.
  # das_centavos vai junto para quem quiser o número (testes, monitor de disponibilidade).
  def self.valores(resultado)
    {
      fator_r: resultado.fator_r && SimplesNacional::Formato.percentual(resultado.fator_r),
      aliquota_nominal: SimplesNacional::Formato.percentual(resultado.faixa.aliquota),
      aliquota_efetiva: SimplesNacional::Formato.percentual(resultado.aliquota_efetiva, 4),
      das: SimplesNacional::Formato.reais(resultado.das),
      das_centavos: resultado.das
    }
  end
end

# Formato que o runtime Ruby da Vercel espera: um Proc chamado Handler.
Handler = proc do |request, response|
  # O servidor da Vercel entrega os parâmetros como bytes, sem encoding.
  parametros = request.query.to_h { |nome, valor| [nome, valor.to_s.dup.force_encoding(Encoding::UTF_8)] }
  status, corpo = CalcularApi.responder(parametros)
  response.status = status
  response["Content-Type"] = "application/json; charset=utf-8"
  # A resposta só depende da URL: a Vercel guarda em cache por um dia e responde sem rodar
  # a função de novo (economiza execuções no plano gratuito).
  response["Cache-Control"] = "public, max-age=0, s-maxage=86400" if status == 200
  response.body = JSON.generate(corpo)
end
