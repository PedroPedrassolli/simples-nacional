# frozen_string_literal: true

module SimplesNacional
  # Monta a explicação da conta (a memória de cálculo), um passo por etapa, com a base legal
  # de cada uma. A página só mostra estes textos: a regra fica toda aqui no Ruby.
  #
  # grupo: a parte da memória de cálculo ("Receitas dos meses anteriores", "Receita 1: ...",
  # "Sublimite e limite", "Fora do DAS", "Total do mês").
  module Passos
    Passo = Data.define(:titulo, :texto, :fonte, :grupo) do
      def initialize(titulo:, texto:, fonte:, grupo: nil) = super
    end

    ROMANOS = { 1 => "I", 2 => "II", 3 => "III", 4 => "IV", 5 => "V" }.freeze

    def self.romano(numero) = ROMANOS.fetch(numero)

    def self.montar(resultado)
      dados = resultado.dados
      anteriores = [*inicio(dados), *historico(dados), *fator_r(resultado.fator, dados)]
      grupos = [["Receitas dos meses anteriores", anteriores],
                *resultado.atividades.map { |apurada| PassosDaAtividade.grupo(apurada, resultado) },
                ["Sublimite e limite", PassoDoSublimite.montar(resultado)],
                ["Fora do DAS", fora_do_das(resultado.fora_do_das)], ["Total do mês", [das(resultado)]]]
      grupos.flat_map { |grupo, passos| passos.map { |passo| passo.with(grupo:) } }
    end

    # Empresa em início de atividade: como a RBT12 (e a folha, no Fator R) foi anualizada.
    def self.inicio(dados)
      return [] if dados.meses.nil?

      textos = [texto_do_inicio(dados)]
      textos += InicioDeAtividade.primeira_faixa?(dados.meses, dados.regras) ? [] : contas_do_inicio(dados)
      [Passo.new(titulo: "Início de atividade", texto: textos.join(" "), fonte: fonte_do_inicio(dados))]
    end

    def self.texto_do_inicio(dados)
      comeco = "A empresa começou em #{Formato.mes(dados.inicio)}"
      if dados.primeira_faixa
        return "#{comeco}: este é o #{dados.meses + 1}º mês de atividade. No 1º e no 2º mês, a conta usa as " \
               "alíquotas da 1ª faixa, sem RBT12."
      end
      return "#{comeco}, o próprio mês de apuração." if dados.meses.zero?

      quantos = dados.meses == 1 ? "1 mês" : "#{dados.meses} meses"
      "#{comeco}: #{quantos} de atividade antes de #{Formato.mes(dados.periodo)}."
    end

    def self.contas_do_inicio(dados)
      contas = [conta_anualizada("A RBT12", "a receita do mês", dados.interno, dados)]
      if dados.exportacao.do_mes.positive?
        contas << conta_anualizada("A RBT12 da exportação", "a receita de exportação do mês", dados.exportacao, dados)
      end
      contas << conta_anualizada("A folha de salários do Fator R", "a folha do mês", dados.folha, dados) if dados.folha
      contas
    end

    # "A RBT12 é a receita do mês × 12: R$ 20.000,00 × 12 = R$ 240.000,00." ou, depois,
    # "A RBT12 é a média dos meses anteriores × 12: R$ 100.000,00 ÷ 4 × 12 = ...".
    def self.conta_anualizada(nome, do_mes, valores, dados)
      divisor = InicioDeAtividade.divisor(dados.meses, dados.regras)
      resultado = Formato.reais(valores.anualizada)
      if divisor.zero?
        valor = valores.respond_to?(:do_mes) ? valores.do_mes : valores.informada
        return "#{nome} é #{do_mes} × 12: #{Formato.reais(valor)} × 12 = #{resultado}."
      end

      meses = dados.regras.rbt12_sem_o_mes_anterior ? "meses antes do mês anterior" : "meses anteriores"
      "#{nome} é a média dos #{meses} × 12: #{Formato.reais(valores.informada)} ÷ #{divisor} × 12 = #{resultado}."
    end

    def self.fonte_do_inicio(dados)
      res = dados.regras.res
      paragrafos = if dados.regras.rbt12_sem_o_mes_anterior
                     dados.primeira_faixa ? "art. 22, § 2º, I" : "art. 22, § 2º, II, e § 4º"
                   else
                     dados.meses.zero? ? "art. 22, § 2º" : "art. 22, §§ 3º e 4º"
                   end
      paragrafos += ", e art. 26, § 4º" if dados.folha
      "LC 123/2006, art. 18, § 2º; #{res}, #{paragrafos}"
    end

    # Mês a mês: o que a calculadora somou.
    def self.historico(dados)
      return [] unless dados.historico

      [Passo.new(titulo: "Mês a mês", texto: PassosDoHistorico.texto(dados),
                 fonte: "LC 123/2006, art. 18, § 1º; #{dados.regras.res}, arts. 21, II, a, e 26")]
    end

    def self.fator_r(fator, dados)
      return [] unless fator

      fonte = "LC 123/2006, art. 18, §§ 5º-J, 5º-K, 5º-M e 24"
      fonte += "; #{dados.regras.res}, art. 26, § 6º" if fator.inicial
      [Passo.new(titulo: "Fator R", texto: texto_do_fator_r(fator, dados), fonte:)]
    end

    def self.texto_do_fator_r(fator, dados)
      if fator.inicial
        return "No 1º e no 2º mês de atividade, o Fator R é 28%: as receitas do Fator R vão para o Anexo III."
      end

      exportacao = dados.exportacao.anualizada.positive? ? " (mercado interno e exportação)" : ""
      "Folha de salários ÷ RBT12#{exportacao} = #{Formato.reais(fator.folha)} ÷ #{Formato.reais(fator.rbt12)} = " \
        "#{Formato.percentual(fator.fator)}. #{regra_do_fator_r(fator.anexo)}."
    end

    def self.regra_do_fator_r(anexo)
      return "Como é 28% ou mais, a atividade vai para o Anexo III" if anexo == 3

      "Como é menor que 28%, a atividade vai para o Anexo V"
    end

    def self.fora_do_das(estimativas)
      estimativas.map do |estimativa|
        Passo.new(titulo: "#{estimativa.tributo} fora do DAS", fonte: estimativa.fonte,
                  texto: [estimativa.texto, estimativa.falta].compact.join(" "))
      end
    end

    # O passo final: o DAS do mês.
    def self.das(resultado)
      return PassosDaAtividade.das_de_uma(resultado) if resultado.atividades.size == 1

      valores = resultado.atividades.map { |apurada| Formato.reais(apurada.valor) }
      Passo.new(titulo: "DAS estimado", fonte: "LC 123/2006, art. 18, § 3º",
                texto: "Soma das receitas: #{valores.join(' + ')} = #{Formato.reais(resultado.das)}.")
    end

    private_class_method :inicio, :texto_do_inicio, :contas_do_inicio, :conta_anualizada, :fonte_do_inicio,
                         :historico, :fator_r, :texto_do_fator_r, :regra_do_fator_r, :fora_do_das, :das
  end
end
