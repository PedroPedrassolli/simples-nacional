# frozen_string_literal: true

module SimplesNacional
  # O passo "Sublimite do ICMS" (ou do ISS, ou dos dois, e do IBS a partir de 2027). A regra
  # está em Sublimite; aqui só o texto. O limite do Simples e a exportação ficam em PassoDoLimite.
  module PassoDoSublimite
    # Todos os passos do grupo "Sublimite e limite".
    def self.montar(resultado)
      [*sublimite(resultado), *PassoDoLimite.montar(resultado)]
    end

    # Os impostos locais que as receitas do mercado interno pagariam no DAS.
    def self.locais(resultado)
      internas = resultado.atividades.reject { |apurada| apurada.atividade.exportacao? }
      nomes = internas.flat_map { |apurada| locais_da(apurada) }
      nomes -= ["IBS"] if resultado.dados.ibs_cbs_fora
      Tabelas::LOCAIS & nomes
    end

    def self.locais_da(apurada)
      tipo = apurada.atividade.tipo
      Reparticao.locais_do(apurada.tabela) - tipo.tira + (tipo.icms_do_anexo_i ? ["ICMS"] : [])
    end

    def self.sublimite(resultado)
      locais = locais(resultado)
      return [] if locais.empty?

      dados = resultado.dados
      textos = [texto_do_ano_anterior(dados, locais), texto_do_ano(resultado, locais)].compact
      return [] if textos.empty?

      [Passos::Passo.new(titulo: "Sublimite #{Formato.lista(locais, 'do')}", texto: textos.join(" "),
                         fonte: fonte(dados.situacao, dados.regras))]
    end

    # singular ou plural, conforme a quantidade de impostos.
    def self.conforme(locais, singular, plural) = locais.size == 1 ? singular : plural

    def self.texto_do_ano_anterior(dados, locais)
      ano = dados.periodo.year - 1
      return fora_pelo_ano_anterior(dados, locais, ano) if dados.situacao.motivo == :ano_anterior
      return if dados.inicio&.year.to_i > ano
      return "A receita de #{ano} não passou do sublimite." if dados.receita_ano_anterior

      sem_o_ano_anterior(locais, ano) if pode_ter_passado?(dados)
    end

    # Só vale avisar quando a RBT12 passa do sublimite (senão o ano anterior também não passou).
    def self.pode_ter_passado?(dados) = dados.interno.anualizada > dados.situacao.sublimite

    def self.sem_o_ano_anterior(locais, ano)
      "Sem a receita de #{ano}, a conta considera que ela não passou do sublimite; se passou, " \
        "#{Formato.lista(locais)} de #{ano + 1} #{conforme(locais, 'é pago', 'são pagos')} fora do DAS."
    end

    def self.fora_pelo_ano_anterior(dados, locais, ano)
      "A receita de #{ano}, #{Formato.reais(dados.receita_ano_anterior)}, passou do sublimite. Por isso, " \
        "em #{ano + 1} #{Formato.lista(locais)} não #{conforme(locais, 'entra', 'entram')} no DAS: " \
        "#{conforme(locais, 'é pago', 'são pagos')} à parte, pelas regras normais."
    end

    def self.texto_do_ano(resultado, locais)
      dados = resultado.dados
      situacao = dados.situacao
      return if situacao.receita_ano.nil? || situacao.motivo == :ano_anterior

      total = Formato.reais(situacao.receita_ano + dados.interno.do_mes)
      "#{texto_do_sublimite(dados)} A receita de #{dados.periodo.year} com este mês é de #{total}" \
        "#{depois_do_total(resultado, locais)}"
    end

    def self.depois_do_total(resultado, locais)
      quem = Formato.lista(locais)
      case resultado.dados.situacao.motivo
      when :inicio then ", mais de 20% acima dele: #{quem} #{conforme(locais, 'sai', 'saem')} do DAS desde o " \
                        "início das atividades."
      when :excesso then ". #{texto_do_excesso(locais)}"
      when :pouco_acima, :muito_acima then ", acima do sublimite. #{PassoDoMajorado.texto(resultado, locais)}"
      else ": não passa do sublimite, e #{quem} #{conforme(locais, 'fica', 'ficam')} no DAS."
      end
    end

    # "Em 2026, o sublimite é de R$ 3.600.000,00 em todos os estados e no DF, conforme a (...)", e o
    # proporcional no ano de início.
    def self.texto_do_sublimite(dados)
      ano = dados.periodo.year
      inteiro = Formato.reais(Sublimite.valor(ano))
      texto = "Em #{ano}, o sublimite é de #{inteiro} em todos os estados e no DF, conforme a " \
              "#{Sublimite.anos.fetch(ano)[:ato]}."
      return texto unless Sublimite.inicio_no_ano?(dados)

      "#{texto} No ano de início, ele é proporcional aos meses de #{Formato.mes(dados.inicio)} a dezembro: " \
        "#{inteiro} ÷ 12 × #{13 - dados.inicio.month} = #{Formato.reais(dados.situacao.sublimite)}."
    end

    def self.texto_do_excesso(locais)
      "Até o mês anterior, a receita do ano já tinha passado do sublimite em mais de 20%: desde o mês seguinte " \
        "ao excesso, #{Formato.lista(locais)} não #{conforme(locais, 'entra', 'entram')} no DAS e " \
        "#{conforme(locais, 'é pago', 'são pagos')} à parte."
    end

    def self.fonte(situacao, regras)
      case situacao.motivo
      when :ano_anterior then "LC 123/2006, art. 20, §§ 1º e 1º-A; #{regras.res}, art. 12"
      when :pouco_acima, :muito_acima
        return "LC 123/2006, art. 18, §§ 17 e 17-A; Res. CGSN 140/2018, arts. 12 e 24, I" if regras.majora_excesso

        "LC 123/2006, art. 13-A; #{regras.res}, arts. 9º, 12 e 24"
      else "LC 123/2006, arts. 13-A, 19 e 20; #{regras.res}, arts. 9º e 12"
      end
    end

    private_class_method :locais_da, :sublimite, :conforme, :texto_do_ano_anterior, :fora_pelo_ano_anterior,
                         :pode_ter_passado?, :sem_o_ano_anterior, :texto_do_ano, :depois_do_total, :texto_do_sublimite,
                         :texto_do_excesso, :fonte
  end
end
