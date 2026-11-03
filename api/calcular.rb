# frozen_string_literal: true

require "json"
require_relative "../lib/simples_nacional"

# Função da Vercel que a página chama. Toda a regra fica na biblioteca (lib/); aqui só
# se lê a URL, confere o formato dos números e monta o JSON.
#
# Uma receita só (o jeito de antes, que continua valendo):
#   GET /api/calcular?periodo=2026-03&rbt12=500000.00&receita_mes=40000.00&anexo=3
#   GET /api/calcular?periodo=2026-03&rbt12=500000.00&receita_mes=40000.00&anexo=fator_r&folha12=150000.00
#   GET /api/calcular?periodo=2026-03&inicio=2025-11&rbt12=100000.00&receita_mes=30000.00&anexo=1
#   GET /api/calcular?periodo=2026-10&rbt12=3900000.00&receita_mes=400000.00&anexo=1&receita_ano=3300000.00
#
# Várias receitas (segregação), com os qualificadores depois do valor, separados por "+":
#   GET /api/calcular?periodo=2026-03&rbt12=500000.00&atividades=revenda:30000.00:st_icms;servicos_3:10000.00
#
# Mês a mês, no lugar de rbt12, folha12 e receita_ano: um parâmetro por mês, com a receita,
# a exportação e a folha (as duas últimas podem faltar):
#   GET /api/calcular?periodo=2026-03&anexo=3&receita_mes=40000.00&mes_2026-02=42000.00&mes_2026-01=38000:0:9000...
#
# Isenção ou redução de ICMS e ISS vai como qualificador, com o % depois do "=":
#   atividades=servicos_3:10000.00:reducao_iss=40
#
# Pagamento em atraso (multa e juros): pagamento=2026-06-10. MEI: regime=mei, com
# mei_atividade (comercio, industria, servicos ou comercio_servicos) e, se quiser, receita_ano.
#
# Os valores vão em reais, com ponto e até duas casas ("500000.00"); a página converte o
# que a pessoa digitou ("500.000,00") antes de chamar. Percentuais em % ("3.5" = 3,5%).
# Os demais parâmetros estão no README.
module CalcularApi
  # Até R$ 9.999.999,99: cobre o limite do Simples e recusa textos enormes logo de cara.
  VALOR = /\A(\d{1,7})(?:\.(\d{1,2}))?\z/
  PERCENTUAL = /\A\d{1,3}(?:\.\d{1,4})?\z/
  MES = /\Ames_(\d{4}-\d{2})\z/

  ANEXOS = { "1" => 1, "2" => 2, "3" => 3, "4" => 4, "5" => 5, "fator_r" => :fator_r }.freeze

  NOMES = {
    "rbt12" => "a receita bruta dos meses anteriores (RBT12)", "receita_mes" => "a receita do mês",
    "folha12" => "a folha de salários", "receita_ano" => "a receita do ano até o mês anterior",
    "receita_ano_anterior" => "a receita do ano anterior", "rbt12_exportacao" => "a RBT12 da exportação",
    "receita_mes_anterior" => "a receita do mês anterior", "creditos_icms" => "os créditos de ICMS",
    "creditos_ibs" => "os créditos de IBS", "creditos_cbs" => "os créditos de CBS",
    "folha_empregados" => "a folha dos empregados", "pro_labore" => "o pró-labore",
    "receita_ano_exportacao" => "a receita de exportação do ano", "icms_fixo" => "o valor fixo do ICMS",
    "iss_fixo" => "o valor fixo do ISS", "st_valor" => "a venda com substituição tributária",
    "st_ipi" => "a soma do IPI e dos encargos da venda", "difal_valor" => "a soma das compras de outros estados",
    "salario_minimo" => "o salário mínimo"
  }.freeze

  ACUMULADOS = %w[rbt12 rbt12_exportacao folha12 receita_ano receita_ano_anterior receita_mes_anterior
                  receita_ano_exportacao].freeze

  # Parâmetro com problema: vira resposta 400 com a mensagem.
  class ParametroInvalido < StandardError; end

  # Devolve [status HTTP, corpo da resposta].
  def self.responder(parametros)
    return [200, Mei.corpo(Mei.calcular(parametros))] if texto(parametros, "regime") == "mei"

    resultado = SimplesNacional.calcular(periodo: texto(parametros, "periodo"), inicio: texto(parametros, "inicio"),
                                         **receitas_do_mes(parametros), **acumulados(parametros),
                                         ibs_cbs_fora: texto(parametros, "ibs_cbs_fora") == "1",
                                         fora_do_das: ForaDoDas.ler(parametros),
                                         valores_fixos: valores_fixos(parametros),
                                         pagamento: texto(parametros, "pagamento"))
    [200, Corpo.montar(resultado)]
  rescue ParametroInvalido, SimplesNacional::Calculo::EntradaInvalida => e
    [400, { erro: e.message }]
  end

  # icms_fixo=108.00&iss_fixo=162.75 → { "ICMS" => 10_800, "ISS" => 16_275 } (só os informados).
  def self.valores_fixos(parametros)
    { "ICMS" => "icms_fixo", "ISS" => "iss_fixo" }.filter_map do |tributo, nome|
      valor = opcional(parametros, nome)
      [tributo, valor] if valor
    end.to_h
  end

  # atividades=... (várias receitas) ou anexo + receita_mes (uma só).
  def self.receitas_do_mes(parametros)
    lista = texto(parametros, "atividades")
    return { atividades: atividades(lista) } if lista

    anexo = ANEXOS[parametros["anexo"].to_s] || raise(ParametroInvalido, "Escolha o anexo: 1, 2, 3, 4, 5 ou fator_r.")
    { anexo:, receita_mes: centavos(parametros, "receita_mes") }
  end

  # "revenda:30000.00:st_icms+monofasico;servicos_3:10000.00" → lista de hashes.
  def self.atividades(texto)
    texto.split(";").first(SimplesNacional::AtividadesInformadas::MAXIMO + 1).map do |parte|
      tipo, valor, opcoes = parte.split(":", 3)
      { tipo:, receita: centavos({ "receita_mes" => valor }, "receita_mes"), opcoes: opcoes.to_s.split("+") }
    end
  end

  # Totais (rbt12, folha12...) ou mês a mês (mes_AAAA-MM). A folha só vale no Fator R.
  def self.acumulados(parametros)
    valores = ACUMULADOS.to_h { |nome| [nome.to_sym, opcional(parametros, nome)] }
    valores[:folha12] = nil unless fator_r?(parametros)
    historico = historico(parametros)
    historico.empty? ? valores : valores.merge(historico:)
  end

  def self.fator_r?(parametros)
    parametros["anexo"].to_s == "fator_r" || parametros["atividades"].to_s.include?("fator_r")
  end

  # { "2026-02" => { receita:, exportacao:, folha: } } a partir de mes_2026-02=42000.00:0:9000.00
  def self.historico(parametros)
    parametros.filter_map do |nome, valor|
      mes = MES.match(nome.to_s.scrub)&.captures&.first
      [mes, mes_do_historico(valor, mes)] if mes
    end.first(25).to_h
  end

  # "42000.00:0:9000.00" → { receita:, exportacao:, folha: } (as duas últimas valem 0 se faltarem).
  def self.mes_do_historico(valor, mes)
    receita, exportacao, folha = valor.to_s.split(":", 3).map { |parte| centavos({ "x" => parte }, "x", mes) }
    { receita:, exportacao: exportacao || 0, folha: folha || 0 }
  end

  # Parâmetro de texto (os meses "AAAA-MM"); vazio vira nil. A biblioteca confere o formato.
  def self.texto(parametros, nome)
    texto = parametros[nome].to_s.scrub.strip
    texto unless texto.empty?
  end

  # Valor que pode faltar (a biblioteca diz quando ele é necessário): vazio vira nil.
  def self.opcional(parametros, nome) = texto(parametros, nome) && centavos(parametros, nome)

  # "500000.5" → 50_000_050 centavos. mes: para a mensagem do mês a mês.
  def self.centavos(parametros, nome, mes = nil)
    # scrub troca bytes que não são UTF-8 válido por "�". Sem ele, um texto quebrado
    # (ex.: %FF na URL) levanta ArgumentError no match e vira erro 500 em vez de 400.
    reais, decimais = VALOR.match(parametros[nome].to_s.scrub)&.captures
    return (reais.to_i * 100) + decimais.to_s.ljust(2, "0").to_i if reais
    raise ParametroInvalido, "No mês a mês, informe #{mes} como número, por exemplo 40000.00." if mes

    raise ParametroInvalido, "Informe #{NOMES.fetch(nome, 'a receita')} como número, por exemplo 500000.00."
  end

  private_class_method :valores_fixos, :receitas_do_mes, :atividades, :acumulados, :fator_r?, :historico,
                       :mes_do_historico

  # O que fica fora do DAS: alíquotas em % ("3.5"), valores em reais, o RAT (1, 2 ou 3) e o FAP.
  module ForaDoDas
    ALIQUOTAS = %w[aliquota_iss aliquota_icms aliquota_ibs aliquota_cbs st_mva st_aliquota_interna st_aliquota_propria
                   difal_aliquota_interna difal_aliquota_interestadual].freeze
    FAP = /\A\d(?:\.\d{1,4})?\z/
    VALORES_FORA = %w[creditos_icms creditos_ibs creditos_cbs folha_empregados pro_labore st_valor st_ipi
                      difal_valor].freeze

    def self.ler(parametros)
      valores = ALIQUOTAS.to_h { |nome| [nome.to_sym, percentual(parametros, nome)] }
      VALORES_FORA.each { |nome| valores[nome.to_sym] = CalcularApi.opcional(parametros, nome) }
      valores.merge(rat: CalcularApi.texto(parametros, "rat")&.then { |rat| inteiro_do_rat(rat) }, fap: fap(parametros))
    end

    def self.inteiro_do_rat(texto)
      /\A[123]\z/.match?(texto) ? texto.to_i : raise(ParametroInvalido, "O RAT precisa ser 1, 2 ou 3.")
    end

    # "3.5" → 3,5% (Rational(35, 1000)). Vazio vira nil.
    def self.percentual(parametros, nome)
      valor = CalcularApi.texto(parametros, nome)
      return if valor.nil?
      raise ParametroInvalido, "Informe #{nome.tr('_', ' ')} em %, como 3.5." unless PERCENTUAL.match?(valor)

      Rational(valor) / 100
    end

    def self.fap(parametros)
      valor = CalcularApi.texto(parametros, "fap")
      return if valor.nil?
      raise ParametroInvalido, "Informe o FAP como número, por exemplo 1.0000." unless FAP.match?(valor)

      Rational(valor)
    end

    private_class_method :inteiro_do_rat, :percentual, :fap
  end

  # O MEI (regime=mei): o mês, a atividade e, se quiser, o início, a receita do ano, o salário
  # mínimo (obrigatório em 2027 e 2028, ainda sem decreto) e a data do pagamento.
  module Mei
    F = SimplesNacional::Formato

    def self.calcular(parametros)
      SimplesNacional.calcular_mei(
        periodo: CalcularApi.texto(parametros, "periodo"), atividade: CalcularApi.texto(parametros, "mei_atividade"),
        transportador: CalcularApi.texto(parametros, "transportador") == "1",
        inicio: CalcularApi.texto(parametros, "inicio"), receita_ano: CalcularApi.opcional(parametros, "receita_ano"),
        salario_minimo: CalcularApi.opcional(parametros, "salario_minimo"),
        pagamento: CalcularApi.texto(parametros, "pagamento")
      )
    end

    def self.corpo(resultado)
      periodo = resultado.periodo
      { regime: "mei", periodo: periodo.strftime("%Y-%m"), periodo_nome: F.mes(periodo), ano: periodo.year,
        atividade: resultado.atividade.nome, transportador: resultado.transportador }.merge(valores(resultado))
    end

    # O DAS, os valores fixos (a CBS e o IBS de 2027 têm milésimos), o limite e o atraso.
    def self.valores(resultado)
      { das: F.reais(resultado.das), das_centavos: resultado.das,
        tributos: resultado.tributos.map { |tributo| { nome: tributo.nome, valor: F.reais_exatos(tributo.valor) } },
        limite: limite(resultado.limite), atraso: Corpo.atraso(resultado.atraso), passos: resultado.passos.map(&:to_h) }
    end

    def self.limite(limite)
      { limite: F.reais(limite.limite), receita_ano: limite.receita_ano && F.reais(limite.receita_ano),
        excesso: F.reais(limite.excesso), diferenca: limite.diferenca && F.reais(limite.diferenca),
        situacao: limite.situacao }
    end

    private_class_method :valores, :limite
  end

  # O JSON da resposta: percentuais e dinheiro já no formato brasileiro, para a página só mostrar.
  # Os campos do topo (anexo, faixa, rbt12...) são da primeira receita, como antes da segregação;
  # das_centavos vai junto para quem quiser o número (testes, monitor de disponibilidade).
  module Corpo
    F = SimplesNacional::Formato

    def self.montar(resultado)
      avisos = SimplesNacional::Avisos.montar(resultado)
      fora_do_das = resultado.fora_do_das.map { |item| estimativa(item) }
      cabecalho(resultado).merge(totais(resultado), atividades: atividades(resultado), fora_do_das:,
                                                    passos: resultado.passos.map(&:to_h), aviso: avisos.first, avisos:,
                                                    atraso: atraso(resultado.atraso), tabela: tabela(resultado.anexo))
    end

    # Multa e juros do pagamento em atraso, ou nil (também no MEI).
    def self.atraso(atraso)
      return if atraso.nil?

      { vencimento: F.data(atraso.vencimento), pagamento: F.data(atraso.pagamento), dias: atraso.dias,
        total_centavos: atraso.total }.merge(valores_do_atraso(atraso))
    end

    def self.valores_do_atraso(atraso)
      { multa_percentual: F.percentual(atraso.multa_percentual), multa: F.reais(atraso.multa),
        juros_percentual: F.percentual(atraso.juros_percentual), juros: F.reais(atraso.juros),
        total: F.reais(atraso.total) }
    end

    # O mês e a primeira receita (os campos de antes da segregação).
    def self.cabecalho(resultado)
      periodo = resultado.periodo
      { periodo: periodo.strftime("%Y-%m"), periodo_nome: F.mes(periodo), ano: periodo.year,
        fator_r: resultado.fator_r && F.percentual(resultado.fator_r) }.merge(da_tabela(resultado.atividades.first))
    end

    def self.da_tabela(apurada)
      { anexo: apurada.tabela.numero, anexo_nome: apurada.tabela.nome, faixa: apurada.faixa.numero,
        rbt12: F.reais(apurada.rbt12), aliquota_nominal: F.percentual(apurada.faixa.aliquota) }
    end

    def self.totais(resultado)
      { das: F.reais(resultado.das), das_centavos: resultado.das, receita: F.reais(resultado.receita),
        aliquota_efetiva: F.percentual(resultado.aliquota_efetiva, 4), tributos: tributos(resultado.tributos),
        total_estimado: F.reais(resultado.total_estimado), total_estimado_centavos: resultado.total_estimado }
    end

    def self.atividades(resultado)
      regras = resultado.dados.regras
      resultado.atividades.map { |apurada| identificacao(apurada, regras).merge(conta(apurada)) }
    end

    def self.identificacao(apurada, regras)
      atividade = apurada.atividade
      { numero: apurada.numero, tipo: atividade.tipo.codigo, nome: atividade.tipo.nome,
        opcoes: atividade.opcoes.map { |codigo| nome_da_opcao(codigo, atividade, regras) },
        exportacao: atividade.exportacao?, receita: F.reais(atividade.receita) }
    end

    # "Redução do ISS dada pelo município (40,00%)": a redução vai com o percentual.
    def self.nome_da_opcao(codigo, atividade, regras)
      nome = SimplesNacional::Atividades.opcao(codigo, regras).nome
      tributo = SimplesNacional::Atividades::REDUCOES[codigo]
      tributo ? "#{nome} (#{F.percentual(atividade.reducoes.fetch(tributo))})" : nome
    end

    def self.conta(apurada)
      da_tabela(apurada).merge(aliquota_efetiva: F.percentual(apurada.efetiva, 4),
                               percentual: F.percentual(apurada.total, 4), valor: F.reais(apurada.valor),
                               valor_centavos: apurada.valor, tributos: tributos(apurada.tributos))
    end

    def self.estimativa(estimativa)
      { tributo: estimativa.tributo, base: estimativa.base && F.reais(estimativa.base),
        valor: estimativa.valor && F.reais(estimativa.valor), valor_centavos: estimativa.valor,
        texto: estimativa.texto, falta: estimativa.falta, fonte: estimativa.fonte }
    end

    def self.tabela(anexo) = { fonte: anexo.fonte, redacao: anexo.redacao, vigencia: anexo.vigencia.iso8601 }

    # A divisão do DAS: percentual sobre a receita e valor de cada tributo.
    def self.tributos(lista)
      lista.map do |tributo|
        { nome: tributo.nome, percentual: F.percentual(tributo.percentual, 4), valor: F.reais(tributo.valor),
          valor_centavos: tributo.valor }
      end
    end

    private_class_method :cabecalho, :da_tabela, :totais, :atividades, :identificacao, :nome_da_opcao, :conta,
                         :estimativa, :tabela, :tributos, :valores_do_atraso
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
