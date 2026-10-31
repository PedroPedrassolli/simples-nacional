# frozen_string_literal: true

module SimplesNacional
  # Monta a explicação da conta, um passo por etapa, com a base legal de cada uma.
  # A página só mostra estes textos: a regra fica toda aqui no Ruby.
  module Passos
    Passo = Data.define(:titulo, :texto, :fonte)

    ROMANOS = { 1 => "I", 2 => "II", 3 => "III", 4 => "IV", 5 => "V" }.freeze

    def self.romano(numero) = ROMANOS.fetch(numero)

    # Empresa com menos de 12 meses de atividade: como a RBT12 (e a folha, no Fator R) foi
    # anualizada. Sem início de atividade, nenhum passo.
    def self.inicio(dados)
      return [] if dados.meses.nil?

      receita = conta_anualizada("A RBT12", "a receita do mês", dados.rbt12_informada || dados.receita_mes,
                                 dados.meses, dados.rbt12)
      texto = "#{texto_do_inicio(dados)} #{receita}"
      if dados.folha12
        texto += " #{conta_anualizada('A folha de salários do Fator R', 'a folha do mês', dados.folha_informada,
                                      dados.meses, dados.folha12)}"
      end
      [Passo.new(titulo: "Início de atividade", texto:, fonte: fonte_do_inicio(dados))]
    end

    def self.texto_do_inicio(dados)
      comeco = "A empresa começou em #{Formato.mes(dados.inicio)}"
      return "#{comeco}, o próprio mês de apuração." if dados.meses.zero?

      quantos = dados.meses == 1 ? "1 mês" : "#{dados.meses} meses"
      "#{comeco}: #{quantos} de atividade antes de #{Formato.mes(dados.periodo)}."
    end

    # "A RBT12 é a receita do mês × 12: R$ 20.000,00 × 12 = R$ 240.000,00." ou, depois do
    # 1º mês, "A RBT12 é a média dos meses anteriores × 12: R$ 100.000,00 ÷ 4 × 12 = ...".
    def self.conta_anualizada(nome, do_mes, valor, meses, anualizado)
      resultado = Formato.reais(anualizado)
      return "#{nome} é #{do_mes} × 12: #{Formato.reais(valor)} × 12 = #{resultado}." if meses.zero?

      "#{nome} é a média dos meses anteriores × 12: #{Formato.reais(valor)} ÷ #{meses} × 12 = #{resultado}."
    end

    def self.fonte_do_inicio(dados)
      paragrafos = dados.meses.zero? ? "art. 22, § 2º" : "art. 22, §§ 3º e 4º"
      paragrafos += ", e art. 26, § 4º" if dados.folha12
      "LC 123/2006, art. 18, § 2º; Res. CGSN 140/2018, #{paragrafos}"
    end

    def self.anexo(tabela)
      Passo.new(titulo: "Anexo",
                texto: "Você informou o Anexo #{romano(tabela.numero)}: #{tabela.nome}.",
                fonte: "LC 123/2006, Anexo #{romano(tabela.numero)}")
    end

    def self.fator_r(tabela, rbt12, folha12, fator)
      regra = if tabela.numero == 3
                "Como é 28% ou mais, a atividade vai para o Anexo III"
              else
                "Como é menor que 28%, a atividade vai para o Anexo V"
              end
      Passo.new(titulo: "Fator R",
                texto: "Folha de salários ÷ RBT12 = #{Formato.reais(folha12)} ÷ " \
                       "#{Formato.reais(rbt12)} = #{Formato.percentual(fator)}. #{regra}.",
                fonte: "LC 123/2006, art. 18, §§ 5º-J, 5º-K, 5º-M e 24")
    end

    def self.faixa(tabela, faixa, rbt12)
      Passo.new(titulo: "Faixa",
                texto: "#{texto_da_rbt12(rbt12)} #{faixa.numero}ª faixa do Anexo #{romano(tabela.numero)}, " \
                       "#{limites(tabela, faixa)}: alíquota nominal de #{Formato.percentual(faixa.aliquota)} e " \
                       "parcela a deduzir de #{Formato.reais(Calculo.centavos(faixa.deduzir))}.",
                fonte: "LC 123/2006, art. 18, § 1º, e Anexo #{romano(tabela.numero)}")
    end

    # O começo do passo da faixa, com as duas exceções da RBT12.
    def self.texto_da_rbt12(rbt12)
      if rbt12.zero?
        return "A RBT12 é zero. Só para achar a alíquota, a conta usa R$ 1,00 (Res. CGSN 140/2018, art. 21, " \
               "parágrafo único), que fica na"
      end
      return "A RBT12 é de #{Formato.reais(rbt12)} e fica na" if rbt12 <= Entrada::TETO

      "A RBT12 é de #{Formato.reais(rbt12)}, acima do limite de #{Formato.reais(Entrada::TETO)}: a conta usa a " \
        "última faixa (Res. CGSN 140/2018, art. 22, § 5º), a"
    end

    # "até R$ 180.000,00" na 1ª faixa; "de R$ 180.000,01 a R$ 360.000,00" nas outras.
    def self.limites(tabela, faixa)
      ate = Formato.reais(Calculo.centavos(faixa.ate))
      return "até #{ate}" if faixa.numero == 1

      anterior = tabela.faixas[faixa.numero - 2]
      "de #{Formato.reais(Calculo.centavos(anterior.ate) + 1)} a #{ate}"
    end

    def self.aliquota_efetiva(faixa, rbt12, efetiva)
      conta = "(#{Formato.reais(rbt12)} × #{Formato.percentual(faixa.aliquota)} − " \
              "#{Formato.reais(Calculo.centavos(faixa.deduzir))}) ÷ #{Formato.reais(rbt12)}"
      Passo.new(titulo: "Alíquota efetiva",
                texto: "(RBT12 × alíquota nominal − parcela a deduzir) ÷ RBT12 = #{conta} = " \
                       "#{Formato.percentual(efetiva, 4)}.",
                fonte: "LC 123/2006, art. 18, § 1º-A")
    end

    # efetiva: a alíquota da fórmula; total: a soma dos percentuais dos tributos (os dois
    # só são diferentes quando o ICMS ou o ISS é calculado à parte, como na 6ª faixa).
    def self.das(receita_mes, efetiva, total, das, tributos)
      aliquota = total == efetiva ? "alíquota efetiva" : "soma dos percentuais dos tributos"
      soma = tributos.sum(&:valor)
      texto = "Receita do mês × #{aliquota} = #{Formato.reais(receita_mes)} × " \
              "#{Formato.percentual(total, 4)} = #{Formato.reais(das)}. A conta usa os percentuais exatos, " \
              "sem cortar casas decimais, e arredonda o resultado para o centavo."
      unless soma == das
        texto += " Cada tributo também é arredondado para o centavo, por isso a soma da tabela " \
                 "(#{Formato.reais(soma)}) pode ficar alguns centavos diferente do total."
      end
      Passo.new(titulo: "DAS estimado", texto:, fonte: "LC 123/2006, art. 18, § 3º")
    end
  end
end
