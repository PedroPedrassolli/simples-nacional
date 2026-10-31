# frozen_string_literal: true

module SimplesNacional
  # O passo "Sublimite do ICMS" (ou do ISS) e o aviso que a página mostra no resultado.
  # A regra está em Sublimite; aqui só o texto.
  module PassoDoSublimite
    # [] quando não houve nada a conferir (receita longe do sublimite e ano anterior em branco).
    def self.montar(tabela, dados)
      local = Reparticao.imposto_local(tabela)
      textos = [texto_do_ano_anterior(dados, local), texto_do_ano(tabela, dados, local)].compact
      return [] if textos.empty?

      [Passos::Passo.new(titulo: "Sublimite do #{local}", texto: textos.join(" "), fonte: fonte(dados.situacao))]
    end

    # Frase curta para o topo do resultado, quando o ICMS/ISS não segue a conta normal.
    def self.aviso(tabela, situacao)
      local = Reparticao.imposto_local(tabela)
      case situacao.tipo
      when :fora
        "O #{local} deste mês não entra no DAS: é pago à parte, pelas regras normais do " \
        "#{local == 'ICMS' ? 'estado' : 'município'}. A calculadora não estima esse valor."
      when :majorado
        "Parte da receita do mês passou do sublimite: o #{local} dessa parte segue outra regra. " \
        "Veja o passo a passo."
      end
    end

    def self.texto_do_ano_anterior(dados, local)
      return texto_fora_pelo_ano_anterior(dados, local) if dados.situacao.motivo == :ano_anterior

      ano = dados.periodo.year - 1
      return if dados.inicio&.year.to_i > ano
      return "A receita de #{ano} não passou do sublimite." if dados.receita_ano_anterior
      return unless dados.rbt12 > dados.situacao.sublimite

      "Sem a receita de #{ano}, a conta considera que ela não passou do sublimite; se passou, o #{local} " \
        "de #{ano + 1} é pago fora do DAS."
    end

    def self.texto_fora_pelo_ano_anterior(dados, local)
      ano = dados.periodo.year
      "A receita de #{ano - 1}, #{Formato.reais(dados.receita_ano_anterior)}, passou do sublimite. Por isso, " \
        "em #{ano} o #{local} não entra no DAS: é pago à parte, pelas regras normais."
    end

    def self.texto_do_ano(tabela, dados, local)
      situacao = dados.situacao
      return if situacao.receita_ano.nil?

      total = Formato.reais(situacao.receita_ano + dados.receita_mes)
      inicio = "#{texto_do_sublimite(dados)} A receita de #{dados.periodo.year} com este mês é de #{total}"
      case situacao.motivo
      when :inicio then "#{inicio}, mais de 20% acima dele: o #{local} sai do DAS desde o início das atividades."
      when :excesso then "#{inicio}. #{texto_do_excesso(local)}"
      when :pouco_acima, :muito_acima then "#{inicio}, acima do sublimite. #{texto_majorado(tabela, dados, local)}"
      else "#{inicio}: não passa do sublimite, e o #{local} fica no DAS."
      end
    end

    # "Em 2026, o sublimite é de R$ 3.600.000,00 em todos os estados e no DF (...)", e o
    # proporcional no ano de início.
    def self.texto_do_sublimite(dados)
      ano = dados.periodo.year
      inteiro = Formato.reais(Sublimite.valor(ano))
      texto = "Em #{ano}, o sublimite é de #{inteiro} em todos os estados e no DF (#{Sublimite.anos.fetch(ano)[:ato]})."
      return texto unless Sublimite.inicio_no_ano?(dados)

      "#{texto} No ano de início, ele é proporcional aos meses de #{Formato.mes(dados.inicio)} a dezembro: " \
        "#{inteiro} ÷ 12 × #{13 - dados.inicio.month} = #{Formato.reais(dados.situacao.sublimite)}."
    end

    def self.texto_do_excesso(local)
      "Até o mês anterior, a receita do ano já tinha passado do sublimite em mais de 20%: desde o mês seguinte " \
        "ao excesso, o #{local} não entra no DAS e é pago à parte."
    end

    # A parte acima do sublimite usa a 5ª faixa com R$ 3.600.000,00 (Res. CGSN 140/2018, art. 24, I, b, 2).
    def self.texto_majorado(tabela, dados, local)
      situacao = dados.situacao
      parte = "A parte da receita do mês acima dele, #{Formato.reais(dados.receita_mes * situacao.fracao)},"
      parte = "Toda a receita do mês" if situacao.fracao == 1
      efeito = situacao.motivo == :pouco_acima ? "só no ano seguinte" : "a partir do mês seguinte"
      "#{parte} paga o #{local} com a alíquota efetiva da 5ª faixa calculada com " \
        "#{Formato.reais(Sublimite::VALOR)}, vezes o percentual do #{local}: #{percentual_majorado(tabela, local)}. " \
        "Pelo tamanho do excesso, o #{local} sai do DAS #{efeito}."
    end

    # "3,9781%", ou "5,8658% (o ISS fica limitado a 5%)".
    def self.percentual_majorado(tabela, local)
      percentual = Reparticao.percentual_majorado(tabela)
      texto = Formato.percentual(percentual, 4)
      local == "ISS" && percentual > Reparticao::TETO_ISS ? "#{texto} (o ISS fica limitado a 5%)" : texto
    end

    def self.fonte(situacao)
      case situacao.motivo
      when :ano_anterior then "LC 123/2006, art. 20, §§ 1º e 1º-A; Res. CGSN 140/2018, art. 12"
      when :pouco_acima, :muito_acima then "LC 123/2006, art. 18, §§ 17 e 17-A; Res. CGSN 140/2018, arts. 12 e 24, I"
      else "LC 123/2006, arts. 13-A, 19 e 20; Res. CGSN 140/2018, arts. 9º e 12"
      end
    end

    private_class_method :texto_do_ano_anterior, :texto_fora_pelo_ano_anterior, :texto_do_ano, :texto_do_sublimite,
                         :texto_do_excesso, :texto_majorado, :percentual_majorado, :fonte
  end
end
