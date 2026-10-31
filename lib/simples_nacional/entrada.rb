# frozen_string_literal: true

require "date"

module SimplesNacional
  # Confere o que a pessoa informou e prepara os números da conta. As mensagens de erro
  # são para quem usa a página.
  #
  # Dinheiro em centavos (Integer). Meses como texto "AAAA-MM".
  module Entrada
    # Só meses de apuração de 2026: a partir de 1º/1/2027 os Anexos I a V passam a ter a
    # redação da LC 214/2025 (art. 519; art. 544, III), que a calculadora ainda não tem.
    # https://www.planalto.gov.br/ccivil_03/leis/lcp/lcp214.htm (conferido em 27/10/2026)
    ANO = 2026

    # Limite da empresa de pequeno porte: receita bruta de até R$ 4.800.000,00 no ano
    # (LC 123/2006, art. 3º, II). Uma receita de um mês só acima disso já passa do limite.
    # A RBT12 pode passar dele (art. 22, § 5º, da Res. CGSN 140/2018): quem confere é a
    # receita do ano (ver Sublimite).
    # https://www.planalto.gov.br/ccivil_03/leis/lcp/lcp123.htm (conferido em 27/10/2026)
    TETO = 480_000_000

    MES = /\A(\d{4})-(\d{2})\z/

    # Entrada que a calculadora não aceita.
    class EntradaInvalida < ArgumentError; end

    # periodo e inicio: o 1º dia do mês (Date), inicio é nil sem início de atividade.
    # meses: meses de atividade antes do mês de apuração (0 a 11), ou nil com 12 ou mais.
    # rbt12_informada e folha_informada: o que a pessoa digitou. rbt12 e folha12: o que a
    # conta usa, já anualizado no início de atividade (pode ter fração de centavo).
    # receita_ano: a receita do ano antes do mês de apuração; receita_ano_anterior: a do ano
    # passado (as duas opcionais). situacao: o ICMS/ISS no DAS, fora dele ou com o percentual
    # maior (ver Sublimite).
    Dados = Data.define(:periodo, :inicio, :meses, :anexo, :receita_mes, :rbt12_informada, :rbt12,
                        :folha_informada, :folha12, :receita_ano, :receita_ano_anterior, :situacao)

    def self.conferir(periodo:, anexo:, receita_mes:, rbt12: nil, folha12: nil, inicio: nil, receita_ano: nil,
                      receita_ano_anterior: nil)
      periodo = mes_de_apuracao(periodo)
      inicio, meses = inicio_de_atividade(inicio, periodo)
      conferir_valor(receita_mes, "A receita do mês", teto: TETO)
      dados = Dados.new(periodo:, inicio:, meses:, anexo:, receita_mes:, situacao: nil,
                        **receitas(rbt12, meses, receita_mes, periodo), **folhas(folha12, anexo, meses, periodo),
                        receita_ano: opcional(receita_ano, "A receita do ano até o mês anterior"),
                        receita_ano_anterior: opcional(receita_ano_anterior, "A receita do ano anterior"))
      dados.with(situacao: Sublimite.situacao(dados))
    end

    def self.mes_de_apuracao(texto)
      periodo = mes(texto) || raise(EntradaInvalida, "Informe o mês de apuração no formato AAAA-MM, como 2026-03.")
      return periodo if periodo.year == ANO

      raise EntradaInvalida, "Por enquanto a calculadora usa só as regras de #{ANO}: escolha um mês de #{ANO}. " \
                             "As tabelas mudam em 1º/1/2027 (LC 214/2025, art. 519)."
    end

    # [início (Date), meses de atividade antes do mês de apuração], ou [nil, nil].
    def self.inicio_de_atividade(texto, periodo)
      return [nil, nil] if texto.nil?

      inicio = mes(texto) || raise(EntradaInvalida, "Informe o início das atividades no formato AAAA-MM, como 2025-11.")
      meses = ((periodo.year * 12) + periodo.month) - ((inicio.year * 12) + inicio.month)
      raise EntradaInvalida, "O início das atividades não pode ser depois do mês de apuração." if meses.negative?

      [inicio, InicioDeAtividade.meses(meses)]
    end

    # A RBT12 informada e a que a conta usa. No 1º mês de atividade não há receita anterior:
    # a conta usa a receita do próprio mês × 12.
    def self.receitas(valor, meses, receita_mes, periodo)
      return { rbt12_informada: nil, rbt12: receita_mes * 12 } if meses&.zero?

      nome = InicioDeAtividade.nome_da_receita(meses, periodo)
      raise EntradaInvalida, "Informe #{nome}." if valor.nil?

      conferir_valor(valor, maiuscula(nome))
      { rbt12_informada: valor, rbt12: meses ? InicioDeAtividade.anualizar(valor, meses) : valor }
    end

    # Folha de salários do Fator R, pela mesma regra da receita (Res. CGSN 140/2018, art. 26, § 4º).
    def self.folhas(valor, anexo, meses, periodo)
      return { folha_informada: nil, folha12: nil } unless anexo == :fator_r

      nome = InicioDeAtividade.nome_da_folha(meses, periodo)
      raise EntradaInvalida, "Para usar o Fator R, informe #{nome}." if valor.nil?

      conferir_valor(valor, maiuscula(nome))
      { folha_informada: valor, folha12: meses ? InicioDeAtividade.anualizar(valor, meses) : valor }
    end

    # Valor que pode faltar: nil continua nil.
    def self.opcional(valor, nome)
      conferir_valor(valor, nome) unless valor.nil?
      valor
    end

    def self.maiuscula(texto) = texto.sub(/\A./, &:upcase)

    # "2026-03" → 1º/3/2026; nil se o texto não for um mês. O scrub evita o ArgumentError
    # da expressão regular com bytes que não são UTF-8 válido.
    def self.mes(texto)
      ano, numero = MES.match(texto.to_s.scrub)&.captures&.map(&:to_i)
      Date.new(ano, numero, 1) if ano && (1..12).cover?(numero)
    end

    # Só a receita do mês precisa ser maior que zero e tem teto (o limite do ano); as receitas
    # anteriores e a folha podem ser zero.
    def self.conferir_valor(valor, nome, teto: nil)
      raise EntradaInvalida, "#{nome} precisa ser um número inteiro de centavos." unless valor.is_a?(Integer)
      raise EntradaInvalida, "#{nome} precisa ser maior que zero." if teto && valor < 1
      raise EntradaInvalida, "#{nome} não pode ser negativa." if valor.negative?
      return if teto.nil? || valor <= teto

      raise EntradaInvalida, "#{nome} passa de #{Formato.reais(teto)}, o limite do Simples Nacional para a " \
                             "empresa de pequeno porte (LC 123/2006, art. 3º, II)."
    end

    private_class_method :mes_de_apuracao, :inicio_de_atividade, :receitas, :folhas, :opcional, :maiuscula, :mes,
                         :conferir_valor
  end
end
