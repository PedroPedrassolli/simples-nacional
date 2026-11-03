# frozen_string_literal: true

module SimplesNacional
  # A conta do DAS do MEI explicada, com a base legal (ver Mei).
  module PassosDoMei
    Passo = Passos::Passo

    def self.montar(resultado)
      [inss(resultado), *fixos(resultado), das(resultado), limite(resultado), PassosDoAtraso.passo(resultado.atraso)]
        .compact.map { |passo| passo.with(grupo: "DAS do MEI") }
    end

    def self.inss(resultado)
      ano = resultado.periodo.year
      oficial = Mei.dados.dig("salario_minimo", ano)
      origem = oficial ? oficial["ato"] : "valor informado: o decreto de #{ano} ainda não saiu"
      percentual = resultado.transportador ? "12%" : "5%"
      quem = resultado.transportador ? " (transportador autônomo de cargas)" : ""
      Passo.new(titulo: "INSS", fonte: "LC 123/2006, art. 18-A, § 3º, IV e V, a; Res. CGSN 140/2018, art. 101, I; " \
                                       "Lei 8.212/1991, art. 21, § 2º",
                texto: "#{percentual} do salário mínimo#{quem}: #{percentual} × " \
                       "#{Formato.reais(resultado.salario_minimo)} (#{origem}) = " \
                       "#{Formato.reais_exatos(resultado.tributos.first.valor)}.")
    end

    # ICMS e ISS (e, de 2027 em diante, CBS e IBS) em valores fixos.
    def self.fixos(resultado)
      outros = resultado.tributos.drop(1)
      return [] if outros.empty?

      lista = outros.map { |tributo| "#{tributo.nome} #{Formato.reais_exatos(tributo.valor)}" }
      [Passo.new(titulo: "Valores fixos", fonte: fonte_dos_fixos(resultado.periodo.year),
                 texto: "#{Formato.juntar(lista)}. #{quem_paga(resultado.atividade)}")]
    end

    def self.quem_paga(atividade)
      locais = { %w[ICMS] => "O ICMS é de quem vende mercadorias (comércio e indústria).",
                 %w[ISS] => "O ISS é de quem presta serviços.",
                 %w[ICMS ISS] => "Comércio e serviços pagam o ICMS e o ISS." }
      locais.fetch(atividade.locais)
    end

    def self.fonte_dos_fixos(ano)
      return "LC 123/2006, art. 18-A, § 3º, V, b e c; Res. CGSN 140/2018, art. 101, II e III" if ano == 2026

      "LC 123/2006, art. 18-A, § 3º, IV, b, e V, b a e, e Anexo VII (LC 214/2025, art. 520 e Anexo XXIII)"
    end

    def self.das(resultado)
      valores = resultado.tributos.map { |tributo| Formato.reais_exatos(tributo.valor) }
      Passo.new(titulo: "DAS do MEI", fonte: "LC 123/2006, art. 18-A, § 3º, V; Res. CGSN 140/2018, art. 101",
                texto: "#{valores.join(' + ')} = #{Formato.reais(resultado.das)}, o mesmo valor todo mês, " \
                       "qualquer que seja a receita.")
    end

    def self.limite(resultado)
      limite = resultado.limite
      return if limite.receita_ano.nil?

      Passo.new(titulo: "Limite do MEI", texto: "#{texto_do_limite(limite)} #{TEXTOS.fetch(limite.situacao)}",
                fonte: "LC 123/2006, art. 18-A, §§ 1º, 7º, III, e 10; Res. CGSN 140/2018, arts. 100 e 115, §§ 8º e 9º")
    end

    def self.texto_do_limite(limite)
      texto = "Limite de #{Formato.reais(limite.limite)} no ano; receita do ano: #{Formato.reais(limite.receita_ano)}."
      return texto unless limite.excesso.positive?

      texto = "#{texto} Excesso: #{Formato.reais(limite.excesso)}."
      return texto if limite.diferenca.nil?

      "#{texto} Diferença estimada sobre o excesso, pela 1ª faixa do anexo: #{Formato.reais(limite.diferenca)}."
    end

    TEXTOS = {
      dentro: "Dentro do limite.",
      ate_vinte_por_cento: "Como o excesso é de até 20%, o MEI vira ME em 1º de janeiro do ano seguinte e paga a " \
                           "diferença sobre o excesso, sem multa, junto com o DAS de janeiro (com comércio e " \
                           "serviços, a conta usa a receita de cada um, na DASN-Simei).",
      desde_janeiro: "Como o excesso passa de 20%, o desenquadramento volta a 1º de janeiro: as receitas do ano são " \
                     "apuradas como ME no PGDAS-D (use a calculadora do Simples), com multa e juros.",
      desde_o_inicio: "Como o excesso passa de 20% no ano de início, o desenquadramento volta ao início das " \
                      "atividades: as receitas são apuradas como ME no PGDAS-D, com multa e juros."
    }.freeze

    private_class_method :inss, :fixos, :quem_paga, :fonte_dos_fixos, :das, :limite, :texto_do_limite
  end
end
