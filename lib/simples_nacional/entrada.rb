# frozen_string_literal: true

require "date"

module SimplesNacional
  # Confere o que a pessoa informou e prepara os números da conta. As mensagens de erro
  # são para quem usa a página.
  #
  # Dinheiro em centavos (Integer). Meses como texto "AAAA-MM".
  module Entrada
    # Limite da empresa de pequeno porte: receita bruta de até R$ 4.800.000,00 no ano
    # (LC 123/2006, art. 3º, II). Acima dele a empresa sai do Simples (ver Limite).
    # https://www.planalto.gov.br/ccivil_03/leis/lcp/lcp123.htm (conferido em 02/11/2026)
    LIMITE = 480_000_000
    TETO = LIMITE # nome antigo, mantido para quem já usava

    MES = /\A(\d{4})-(\d{2})\z/

    # Entrada que a calculadora não aceita.
    class EntradaInvalida < ArgumentError; end

    # As receitas de um mercado. A exportação tem RBT12 própria (Res. CGSN 140/2018, art. 23).
    # informada: o que a pessoa digitou (nil quando não foi pedido). anualizada: o que a conta
    # usa (no início de atividade, a média × 12). do_mes: as receitas do mês nesse mercado.
    Mercado = Data.define(:informada, :anualizada, :do_mes)

    # Folha de salários do Fator R: a informada e a de 12 meses.
    Folha = Data.define(:informada, :anualizada)

    # periodo e inicio: o 1º dia do mês (Date); inicio é nil sem início de atividade.
    # meses: meses de atividade antes do mês de apuração, ou nil quando já vale a regra normal.
    # primeira_faixa: 2027 em diante, no 1º e no 2º mês de atividade (sem RBT12).
    # historico: a janela da RBT12 quando a pessoa usou o mês a mês (lista de Date), ou nil.
    # situacao: o ICMS/ISS, o sublimite e o limite (ver Sublimite).
    Dados = Data.define(:periodo, :regras, :inicio, :meses, :primeira_faixa, :atividades, :interno, :exportacao,
                        :folha, :receita_ano, :receita_ano_anterior, :receita_mes_anterior, :historico,
                        :ibs_cbs_fora, :fora_do_das, :situacao)

    # O jeito antigo de chamar (um anexo e a receita do mês) vira uma atividade só.
    ANEXOS = { 1 => "revenda", 2 => "industria", 3 => "servicos_3", 4 => "servicos_4", 5 => "servicos_5",
               fator_r: "fator_r" }.freeze

    def self.conferir(periodo:, atividades: nil, anexo: nil, receita_mes: nil, rbt12: nil, rbt12_exportacao: nil,
                      folha12: nil, inicio: nil, receita_ano: nil, receita_ano_anterior: nil, receita_mes_anterior: nil,
                      historico: nil, ibs_cbs_fora: false, fora_do_das: {})
      periodo, regras = mes_de_apuracao(periodo)
      inicio, meses = inicio_de_atividade(inicio, periodo, regras)
      lista = Atividades.conferir(atividades || do_anexo(anexo, receita_mes, regras), regras)
      valores = { rbt12:, rbt12_exportacao:, folha12:, receita_ano:, receita_mes_anterior: }
      valores, janela = Historico.de_entrada(historico, valores, periodo, regras, inicio) if historico
      dados = montar({ periodo:, regras:, inicio:, meses: }, lista, valores)
      dados.with(receita_ano_anterior: opcional(receita_ano_anterior, "A receita do ano anterior"), historico: janela,
                 ibs_cbs_fora: conferir_ibs_cbs(ibs_cbs_fora, regras), fora_do_das: ForaDoDas.conferir(fora_do_das))
           .then { |pronto| pronto.with(situacao: Sublimite.situacao(pronto)) }
    end

    # base: periodo, regras, inicio e meses.
    def self.montar(base, lista, valores)
      primeira = InicioDeAtividade.primeira_faixa?(base[:meses], base[:regras])
      contexto = [base[:meses], primeira, base[:periodo], base[:regras]]
      campos = { primeira_faixa: primeira, atividades: lista, receita_ano_anterior: nil, historico: nil,
                 receita_ano: opcional(valores[:receita_ano], "A receita do ano até o mês anterior"),
                 receita_mes_anterior: opcional(valores[:receita_mes_anterior], "A receita do mês anterior"),
                 ibs_cbs_fora: false, fora_do_das: nil, situacao: nil }
      Dados.new(**base, **Acumulados.todos(valores, lista, contexto), **campos)
    end

    def self.mes_de_apuracao(texto)
      periodo = mes(texto) || raise(EntradaInvalida, "Informe o mês de apuração no formato AAAA-MM, como 2026-03.")
      regras = Regras.do_ano(periodo.year)
      return [periodo, regras] if regras

      raise EntradaInvalida, "A calculadora usa as regras de 2026 a 2028: escolha um mês desses anos. Em 2029 " \
                             "as tabelas mudam de novo (LC 214/2025, art. 519)."
    end

    # [início (Date), meses de atividade antes do mês de apuração ou nil], ou [nil, nil].
    def self.inicio_de_atividade(texto, periodo, regras)
      return [nil, nil] if texto.nil?

      inicio = mes(texto) || raise(EntradaInvalida, "Informe o início das atividades no formato AAAA-MM, como 2025-11.")
      meses = ((periodo.year * 12) + periodo.month) - ((inicio.year * 12) + inicio.month)
      raise EntradaInvalida, "O início das atividades não pode ser depois do mês de apuração." if meses.negative?

      [inicio, InicioDeAtividade.meses(meses, regras)]
    end

    # anexo 2 a partir de 2027 continua sendo o Anexo II (com IPI mantido), como antes.
    def self.do_anexo(anexo, receita_mes, regras)
      tipo = ANEXOS[anexo] || raise(EntradaInvalida, "O anexo precisa ser 1, 2, 3, 4, 5 ou :fator_r.")
      opcoes = anexo == 2 && regras.anexo_da_industria != 2 ? ["ipi_mantido"] : []
      [{ tipo:, receita: receita_mes, opcoes: }]
    end

    def self.conferir_ibs_cbs(valor, regras)
      return false unless valor
      return true if regras.ibs_cbs_por_fora

      raise EntradaInvalida, "A opção de pagar o IBS e a CBS fora do DAS só existe a partir de 2027 " \
                             "(Res. CGSN 140/2018, art. 40-C, na redação da Res. CGSN 190/2026)."
    end

    # Valor que pode faltar: nil continua nil.
    def self.opcional(valor, nome)
      conferir_valor(valor, nome) unless valor.nil?
      valor
    end

    # "2026-03" → 1º/3/2026; nil se o texto não for um mês. O scrub evita o ArgumentError
    # da expressão regular com bytes que não são UTF-8 válido.
    def self.mes(texto)
      ano, numero = MES.match(texto.to_s.scrub)&.captures&.map(&:to_i)
      Date.new(ano, numero, 1) if ano && (1..12).cover?(numero)
    end

    # Dinheiro sempre em centavos inteiros e nunca negativo. positivo: precisa ser maior que zero.
    def self.conferir_valor(valor, nome, positivo: false)
      raise EntradaInvalida, "#{nome} precisa ser um número inteiro de centavos." unless valor.is_a?(Integer)
      raise EntradaInvalida, "#{nome} precisa ser maior que zero." if positivo && valor < 1
      raise EntradaInvalida, "#{nome} não pode ser negativa." if valor.negative?
    end

    private_class_method :montar, :mes_de_apuracao, :inicio_de_atividade, :do_anexo, :conferir_ibs_cbs, :opcional
  end
end
