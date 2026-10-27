# frozen_string_literal: true

require "json"
require "br_validators"
require "br_validators/consulta"

# Consulta opcional de CNPJ: mostra quem é a empresa, o CNAE principal e se ela consta
# como optante pelo Simples Nacional. Não muda a conta: o anexo continua sendo escolhido
# por quem usa a calculadora (o CNAE sozinho não decide o anexo).
#
#   GET /api/cnpj?cnpj=11.222.333/0001-81
#
# Usa a gem br_validators: valida o CNPJ antes (CNPJ inválido nem chega à internet) e
# consulta a BrasilAPI, que publica os dados abertos da Receita Federal.
# Só devolve dados da empresa: o quadro de sócios (nomes de pessoas) fica de fora.
module CnpjApi
  FONTE = "BrasilAPI (dados públicos do CNPJ na Receita Federal)"

  # Devolve [status HTTP, corpo da resposta].
  def self.responder(cnpj)
    return [400, { erro: "CNPJ inválido: confira os números." }] unless BrValidators::CNPJ.valid?(cnpj)

    dados = BrValidators::Consulta.cnpj(cnpj)
    return [404, { erro: "Esse CNPJ não foi encontrado na BrasilAPI." }] unless dados

    [200, corpo(cnpj, dados)]
  rescue BrValidators::Consulta::Erro
    [502, { erro: "Não deu para consultar o CNPJ agora. Tente de novo em instantes." }]
  end

  def self.corpo(cnpj, dados)
    {
      cnpj: BrValidators::CNPJ.format(cnpj),
      razao_social: dados["razao_social"],
      situacao: dados["descricao_situacao_cadastral"],
      cnae: { codigo: cnae(dados["cnae_fiscal"]), descricao: dados["cnae_fiscal_descricao"] },
      simples: simples(dados),
      fonte: FONTE
    }
  end

  # 6422100 → "6422-1/00", o jeito como o código da CNAE costuma ser escrito.
  def self.cnae(codigo)
    return nil unless codigo

    texto = codigo.to_s.rjust(7, "0")
    "#{texto[0, 4]}-#{texto[4]}/#{texto[5, 2]}"
  end

  # "optante" só é true quando a BrasilAPI diz que a empresa é optante hoje; a data de
  # opção e a de exclusão vão juntas, porque uma empresa pode ter entrado e saído.
  def self.simples(dados)
    {
      optante: dados["opcao_pelo_simples"] == true,
      desde: data(dados["data_opcao_pelo_simples"]),
      excluida_em: data(dados["data_exclusao_do_simples"])
    }
  end

  # "2007-07-01" → "01/07/2007"; vazio ou outro formato → nil.
  def self.data(texto)
    ano, mes, dia = texto.to_s.match(/\A(\d{4})-(\d{2})-(\d{2})\z/)&.captures
    ano && "#{dia}/#{mes}/#{ano}"
  end
end

# Formato que o runtime Ruby da Vercel espera: um Proc chamado Handler.
Handler = proc do |request, response|
  status, corpo = CnpjApi.responder(request.query["cnpj"].to_s.dup.force_encoding(Encoding::UTF_8))
  response.status = status
  response["Content-Type"] = "application/json; charset=utf-8"
  # Dados de cadastro mudam pouco: um dia de cache na Vercel poupa a BrasilAPI e execuções.
  response["Cache-Control"] = "public, max-age=0, s-maxage=86400" if status == 200
  response.body = JSON.generate(corpo)
end
