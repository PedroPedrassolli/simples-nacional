# frozen_string_literal: true

module SimplesNacional
  # Os passos de uma receita do mês: anexo, faixa, alíquota efetiva, divisão entre os
  # tributos, o que a atividade não paga no DAS e o valor.
  module PassosDaAtividade
    Passo = Passos::Passo

    # [nome do grupo, passos]
    def self.grupo(apurada, resultado)
      dados = resultado.dados
      unica = resultado.atividades.size == 1
      passos = [anexo(apurada, dados), PassoDaFaixa.faixa(apurada, dados),
                PassoDaFaixa.aliquota_efetiva(apurada, dados), PassoDaDivisao.montar(apurada, dados),
                *PassoDosAjustes.montar(apurada, dados)]
      passos << valor(apurada) unless unica && dados.valores_fixos.empty?
      [unica ? "Receita do mês" : "Receita #{apurada.numero}: #{apurada.atividade.tipo.nome}", passos]
    end

    def self.anexo(apurada, dados)
      tabela = apurada.tabela
      tipo = apurada.atividade.tipo
      detalhe = case tipo.anexo
                when :fator_r then ", pelo Fator R"
                when :industria then industria(apurada, dados.regras)
                end
      romano = Passos.romano(tabela.numero)
      Passo.new(titulo: "Anexo", texto: "#{tipo.nome}: Anexo #{romano} (#{tabela.nome})#{detalhe}.",
                fonte: fonte_do_anexo(tipo.fonte, "Anexo #{romano}#{redacao(dados)}"))
    end

    # "LC 123/2006, art. 18, § 4º, I, e Anexo I" (sem repetir a lei) ou, quando a base é a
    # Resolução, "Res. CGSN ...; LC 123/2006, Anexo III".
    def self.fonte_do_anexo(fonte, anexo)
      fonte.start_with?("LC 123/2006") ? "#{fonte}, e #{anexo}" : "#{fonte}; LC 123/2006, #{anexo}"
    end

    def self.industria(apurada, regras)
      return if regras.anexo_da_industria == 2

      if apurada.tabela.numero == 2
        return ". O produto tem IPI mantido (Zona Franca de Manaus), então fica no Anexo II " \
               "(#{regras.res}, art. 25, § 1º, II)"
      end

      ". A partir de 2027, a venda de produto fabricado pela empresa vai para o Anexo I, menos a de produto " \
        "com IPI mantido (#{regras.res}, art. 25, § 1º, I e II)"
    end

    def self.redacao(dados) = dados.regras.anexo_da_industria == 2 ? "" : ", na redação da LC 214/2025"

    def self.valor(apurada)
      receita = apurada.atividade.receita
      Passo.new(titulo: "Valor desta receita", fonte: "LC 123/2006, art. 18, § 3º",
                texto: "Receita × soma dos percentuais = #{Formato.reais(receita)} × " \
                       "#{Formato.percentual(apurada.total, 4)} = #{Formato.reais(apurada.valor)}.")
    end

    # O passo final quando há uma receita só (o mesmo texto de antes da segregação).
    def self.das_de_uma(resultado)
      apurada = resultado.atividades.first
      receita = apurada.atividade.receita
      aliquota = apurada.total == apurada.efetiva ? "alíquota efetiva" : "soma dos percentuais dos tributos"
      texto = "Receita do mês × #{aliquota} = #{Formato.reais(receita)} × " \
              "#{Formato.percentual(apurada.total, 4)} = #{Formato.reais(apurada.valor)}. A conta usa os percentuais " \
              "exatos, sem cortar casas decimais, e arredonda o resultado para o centavo."
      Passo.new(titulo: "DAS estimado", texto: [texto, arredondamento(apurada)].compact.join(" "),
                fonte: "LC 123/2006, art. 18, § 3º")
    end

    def self.arredondamento(apurada)
      soma = apurada.tributos.sum(&:valor)
      return if soma == apurada.valor

      "Cada tributo também é arredondado para o centavo, por isso a soma da tabela (#{Formato.reais(soma)}) pode " \
        "ficar alguns centavos diferente do total."
    end

    private_class_method :anexo, :fonte_do_anexo, :industria, :redacao, :valor, :arredondamento
  end
end
