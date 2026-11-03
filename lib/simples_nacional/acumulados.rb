# frozen_string_literal: true

module SimplesNacional
  # As receitas e a folha dos meses anteriores, como a conta usa: a RBT12 de cada mercado
  # (interno e exportação, que é separada: Res. CGSN 140/2018, art. 23) e a folha do Fator R,
  # já anualizadas no início de atividade (ver InicioDeAtividade).
  module Acumulados
    # { interno:, exportacao:, folha: } para Entrada::Dados.
    def self.todos(valores, lista, contexto)
      { interno: mercado(valores[:rbt12], lista.reject(&:exportacao?), contexto),
        exportacao: mercado(valores[:rbt12_exportacao], lista.select(&:exportacao?), contexto, exportacao: true),
        folha: folha(valores[:folha12], lista, contexto) }
    end

    # contexto: [meses de atividade, primeira_faixa, periodo, regras].
    # No 1º e no 2º mês (2027 em diante) vale a 1ª faixa; no 1º mês em 2026, a receita do mês
    # × 12; nos outros casos, o valor informado. A exportação sem receita no mês pode faltar.
    def self.mercado(valor, atividades, contexto, exportacao: false)
      do_mes = atividades.sum(&:receita)
      sem_informar = sem_informar(do_mes, contexto)
      return Entrada::Mercado.new(informada: nil, anualizada: sem_informar, do_mes:) if sem_informar
      return Entrada::Mercado.new(informada: nil, anualizada: 0, do_mes:) if valor.nil? && exportacao && do_mes.zero?

      valor = informado(valor, nome_do_mercado(contexto, exportacao))
      Entrada::Mercado.new(informada: valor, anualizada: anualizar(valor, contexto), do_mes:)
    end

    # A RBT12 que não depende do que a pessoa informou, ou nil.
    def self.sem_informar(do_mes, contexto)
      meses, primeira, = contexto
      return 0 if primeira

      do_mes * 12 if meses&.zero?
    end

    def self.nome_do_mercado(contexto, exportacao)
      meses, _primeira, periodo, regras = contexto
      nome = InicioDeAtividade.nome_da_receita(meses, periodo, regras)
      exportacao ? nome.sub("a receita bruta", "a receita de exportação") : nome
    end

    # Folha de salários do Fator R, pela mesma regra da receita (Res. CGSN 140/2018, art. 26, § 4º).
    # Sem atividade do Fator R ou no 1º e 2º mês de 2027 (Fator R de 28%), não é pedida.
    def self.folha(valor, atividades, contexto)
      meses, primeira, periodo, regras = contexto
      return if primeira || atividades.none? { |atividade| atividade.tipo.anexo == :fator_r }

      valor = informado(valor, InicioDeAtividade.nome_da_folha(meses, periodo, regras), "Para usar o Fator R, informe")
      Entrada::Folha.new(informada: valor, anualizada: anualizar(valor, contexto))
    end

    def self.informado(valor, nome, pedido = "Informe")
      raise Entrada::EntradaInvalida, "#{pedido} #{nome}." if valor.nil?

      Entrada.conferir_valor(valor, nome.sub(/\A./, &:upcase))
      valor
    end

    def self.anualizar(valor, contexto)
      meses, _primeira, _periodo, regras = contexto
      meses ? InicioDeAtividade.anualizar(valor, meses, regras) : valor
    end

    private_class_method :sem_informar, :nome_do_mercado, :informado, :anualizar
  end
end
