# frozen_string_literal: true

module SimplesNacional
  # Receitas e folhas mês a mês. Em vez de somar a RBT12 na mão, a pessoa digita cada mês
  # anterior e a calculadora soma a janela certa, como o PGDAS-D faz com as declarações
  # já entregues:
  #   - RBT12: os 12 meses antes do mês de apuração (2026) ou os 12 meses antes do mês
  #     anterior (2027 e 2028), contando só desde o início das atividades;
  #   - receita do ano: de janeiro (ou do início) até o mês anterior, para o sublimite e o
  #     limite (a de exportação também, para o limite extra dela);
  #   - folha: a mesma janela da RBT12, para o Fator R.
  # LC 123/2006, art. 18, § 1º; Res. CGSN 140/2018, arts. 21, II, a, e 26 (e a redação da Res. CGSN 190/2026).
  module Historico
    # Um mês do histórico, em centavos. exportacao e folha podem ser zero.
    Mes = Data.define(:receita, :exportacao, :folha)

    # Somas para a conta, nos mesmos campos que a pessoa informaria à mão.
    # meses: a janela da RBT12 (lista de Date), para o passo a passo.
    Totais = Data.define(:rbt12, :rbt12_exportacao, :folha12, :receita_ano, :receita_mes_anterior,
                         :receita_ano_exportacao, :meses)

    # O mês a mês substitui os totais: informar os dois deixaria a dúvida de qual vale.
    # Devolve [os totais no formato dos campos à mão, a janela da RBT12].
    def self.de_entrada(historico, valores, periodo, regras, inicio)
      if valores.values.any?
        raise Entrada::EntradaInvalida, "Use o mês a mês ou os totais (RBT12, folha, receita do ano), não os dois."
      end

      totais = totais(meses(historico, periodo), periodo, regras, inicio)
      [totais.to_h.except(:meses), totais.meses]
    end

    # historico: { Date (1º dia do mês) => Mes }. Levanta EntradaInvalida se faltar um mês.
    def self.totais(historico, periodo, regras, inicio)
      janela = janela(periodo, regras, inicio)
      do_ano = do_ano(periodo, inicio)
      conferir_meses(historico, janela + do_ano)
      rbt12, exportacao, folha = %i[receita exportacao folha].map { |campo| soma(historico, janela, campo) }
      Totais.new(rbt12:, rbt12_exportacao: exportacao, folha12: folha, receita_ano: soma(historico, do_ano, :receita),
                 receita_mes_anterior: historico[periodo.prev_month]&.receita,
                 receita_ano_exportacao: soma(historico, do_ano, :exportacao), meses: janela)
    end

    # { "2025-03" => { receita: 1_000, exportacao: 0, folha: 500 } } → { Date => Mes }
    def self.meses(historico, periodo)
      raise Entrada::EntradaInvalida, "O mês a mês precisa ser uma lista de meses." unless historico.is_a?(Hash)
      raise Entrada::EntradaInvalida, "Informe no máximo 24 meses no mês a mês." if historico.size > 24

      historico.to_h do |texto, valores|
        data = Entrada.mes(texto)
        unless data && data < periodo
          raise Entrada::EntradaInvalida, "No mês a mês, \"#{texto}\" não é um mês anterior ao de apuração."
        end

        [data, mes(valores.to_h, Formato.mes(data))]
      end
    end

    def self.mes(valores, nome)
      campos = { receita: valores[:receita], exportacao: valores[:exportacao] || 0, folha: valores[:folha] || 0 }
      campos.each { |campo, valor| Entrada.conferir_valor(valor, "No mês a mês, #{campo} de #{nome}") }
      Mes.new(**campos)
    end

    # Os meses da RBT12, do mais antigo ao mais novo, sem os anteriores ao início.
    def self.janela(periodo, regras, inicio)
      ultimo = periodo.prev_month(regras.rbt12_sem_o_mes_anterior ? 2 : 1)
      meses_entre([ultimo.prev_month(11), inicio].compact.max, ultimo)
    end

    # De janeiro (ou do início) até o mês anterior ao de apuração.
    def self.do_ano(periodo, inicio)
      meses_entre([periodo.prev_month(periodo.month - 1), inicio].compact.max,
                  periodo.prev_month)
    end

    # Lista de meses (Date) do primeiro ao último, inclusive; vazia se o primeiro vem depois.
    def self.meses_entre(primeiro, ultimo)
      meses = []
      while primeiro <= ultimo
        meses << primeiro
        primeiro = primeiro.next_month
      end
      meses
    end

    def self.conferir_meses(historico, meses)
      falta = meses.find { |mes| !historico.key?(mes) }
      return unless falta

      raise Entrada::EntradaInvalida, "No mês a mês, falta #{Formato.mes(falta)} (use 0 se não houve receita)."
    end

    def self.soma(historico, meses, campo) = meses.sum { |mes| historico.fetch(mes).public_send(campo) }

    private_class_method :totais, :meses, :mes, :do_ano, :meses_entre, :conferir_meses, :soma
  end
end
