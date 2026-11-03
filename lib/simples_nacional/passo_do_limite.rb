# frozen_string_literal: true

module SimplesNacional
  # Textos do mês que passou do sublimite (2026: percentual maior na parte acima dele; a partir
  # de 2027: tudo pela alíquota normal até o impedimento).
  module PassoDoMajorado
    def self.texto(resultado, locais)
      dados = resultado.dados
      situacao = dados.situacao
      unless situacao.fracao_sublimite.positive?
        return "A partir de 2027, a parte da receita acima do sublimite é tributada junto com o resto, pela " \
               "alíquota normal (#{dados.regras.res}, art. 24). #{saem(locais, situacao)}"
      end

      "#{parte(dados, situacao)} paga #{Formato.lista(locais)} com a alíquota efetiva da 5ª faixa calculada com " \
        "#{Formato.reais(Sublimite::VALOR)}, vezes o percentual #{percentuais(resultado, locais)}. " \
        "#{saem(locais, situacao)}"
    end

    def self.saem(locais, situacao)
      efeito = situacao.motivo == :pouco_acima ? "só no ano seguinte" : "a partir do mês seguinte"
      "Pelo tamanho do excesso, #{Formato.lista(locais)} #{locais.size == 1 ? 'sai' : 'saem'} do DAS #{efeito}."
    end

    def self.parte(dados, situacao)
      return "Toda a receita do mês" if situacao.fracao_sublimite == 1

      onde = situacao.fracao_limite.positive? ? "entre o sublimite e o limite" : "acima dele"
      "A parte da receita do mês #{onde}, #{Formato.reais(dados.interno.do_mes * situacao.fracao_sublimite)},"
    end

    # "do ICMS: 3,9781%", ou, com mais de um anexo, "de cada um: ICMS 3,9781% (Anexo I), ...".
    def self.percentuais(resultado, locais)
      pares = pares(resultado, locais)
      return "do #{pares.first[0]}: #{percentual(pares.first)}" if pares.size == 1

      textos = pares.map { |par| "#{par[0]} #{percentual(par)} (Anexo #{Passos.romano(par[1])})" }
      "de cada um: #{Formato.juntar(textos)}"
    end

    # [[imposto, número do anexo, percentual majorado], ...] das receitas do mercado interno.
    def self.pares(resultado, locais)
      tabelas = resultado.atividades.reject { |apurada| apurada.atividade.exportacao? }.map(&:tabela).uniq
      tabelas.flat_map do |tabela|
        majorados = Reparticao.locais_majorados(tabela)
        (majorados.keys & locais).map { |nome| [nome, tabela.numero, majorados[nome]] }
      end
    end

    # "3,9781%", ou "5,8658% (o ISS fica limitado a 5%)".
    def self.percentual((nome, _anexo, valor))
      texto = Formato.percentual(valor, 4)
      nome == "ISS" && valor > Reparticao::TETO_ISS ? "#{texto} (o ISS fica limitado a 5%)" : texto
    end

    private_class_method :saem, :parte, :percentuais, :pares, :percentual
  end

  # O passo "Limite do Simples" (receita do ano acima de R$ 4.800.000,00) e o aviso da exportação.
  module PassoDoLimite
    FONTE = "LC 123/2006, art. 3º, §§ 9º, 9º-A, 10 e 12, e art. 18, §§ 16 e 16-A"

    def self.montar(resultado)
      [limite(resultado.dados), exportacao(resultado)].compact
    end

    def self.limite(dados)
      situacao = dados.situacao
      return unless situacao.exclusao

      Passos::Passo.new(titulo: "Limite do Simples", fonte: "#{FONTE}; #{dados.regras.res}, art. 24, II",
                        texto: "#{texto_do_limite(dados)} #{texto_do_ano(dados)} " \
                               "#{parte(dados, dados.interno.do_mes, situacao.fracao_limite)}Pelo tamanho do " \
                               "excesso, a empresa sai do Simples #{saida(situacao.exclusao, dados.periodo.year)}.")
    end

    def self.texto_do_ano(dados)
      total = Formato.reais(dados.situacao.receita_ano + dados.interno.do_mes)
      "A receita de #{dados.periodo.year} com este mês é de #{total}, acima dele."
    end

    def self.texto_do_limite(dados)
      texto = "O limite do Simples é de #{Formato.reais(Entrada::LIMITE)} por ano."
      return texto unless Sublimite.inicio_no_ano?(dados)

      "#{texto} No ano de início, ele é proporcional: #{Formato.reais(Entrada::LIMITE)} ÷ 12 × " \
        "#{13 - dados.inicio.month} = #{Formato.reais(dados.situacao.limite)}."
    end

    # do_mes: a receita do mês no mercado (interno ou exportação); fracao: a parte acima do limite.
    def self.parte(dados, do_mes, fracao, nome = "receita")
      unless dados.regras.majora_excesso
        return "A partir de 2027, a receita acima do limite é tributada junto com o resto, pela alíquota normal, " \
               "até a exclusão. "
      end
      return "" unless fracao.positive?

      quanto = "A parte da #{nome} do mês acima do limite, #{Formato.reais(do_mes * fracao)},"
      quanto = "Toda a #{nome} do mês" if fracao == 1
      "#{quanto} paga os tributos federais com a alíquota efetiva da 6ª faixa calculada com " \
        "#{Formato.reais(Entrada::LIMITE)}. "
    end

    def self.saida(exclusao, ano)
      exclusao == :mes_seguinte ? "a partir do mês seguinte" : "em 1º de janeiro de #{ano + 1}"
    end

    def self.exportacao(resultado)
      return unless resultado.atividades.any? { |apurada| apurada.atividade.exportacao? }

      dados = resultado.dados
      Passos::Passo.new(titulo: "Exportação", texto: texto_da_exportacao(dados),
                        fonte: "LC 123/2006, art. 3º, §§ 14 e 15; #{dados.regras.res}, arts. 2º, § 1º, 23 e 24, § 8º")
    end

    SEM_A_EXPORTACAO_DO_ANO = "Sem a receita de exportação do ano até o mês anterior, a calculadora não confere " \
                              "esse limite."

    # Limite extra da exportação: dentro, acima ou sem a receita do ano para conferir.
    def self.texto_da_exportacao(dados)
      situacao = dados.situacao_exportacao
      texto = "A receita de exportação tem RBT12 própria e um limite extra, igual ao do mercado interno " \
              "(#{Formato.reais(situacao.limite)}#{' no ano de início' if Sublimite.inicio_no_ano?(dados)})."
      "#{texto} #{situacao.receita_ano.nil? ? SEM_A_EXPORTACAO_DO_ANO : conferencia_da_exportacao(dados, situacao)}"
    end

    # Com a receita de exportação do ano: dentro ou acima do limite.
    def self.conferencia_da_exportacao(dados, situacao)
      do_mes = dados.exportacao.do_mes
      total = "Com este mês, a exportação do ano soma #{Formato.reais(situacao.receita_ano + do_mes)}"
      return "#{total}, dentro do limite." unless situacao.exclusao

      "#{total}, acima dele. #{parte(dados, do_mes, situacao.fracao_limite, 'exportação')}" \
        "Pelo tamanho do excesso, a empresa sai do Simples #{saida(situacao.exclusao, dados.periodo.year)}."
    end

    private_class_method :limite, :texto_do_limite, :texto_do_ano, :parte, :exportacao, :texto_da_exportacao,
                         :conferencia_da_exportacao
  end
end
