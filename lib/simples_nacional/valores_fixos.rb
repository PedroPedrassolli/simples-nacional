# frozen_string_literal: true

module SimplesNacional
  # ICMS e ISS em valor fixo mensal: o estado ou o município pode cobrar um valor fixo da ME
  # que teve até R$ 360.000,00 de receita no ano anterior, e o escritório de serviços contábeis
  # paga o ISS em valor fixo pela lei do município. O valor fixo entra no DAS no lugar do
  # percentual do imposto (LC 123/2006, art. 18, §§ 18, 18-A, 20 e 22-A; Res. CGSN 140/2018,
  # arts. 33 e 34).
  #
  # A calculadora usa o valor que a pessoa informa (é o da lei do estado ou do município) e só
  # avisa quando ele parece fora das regras do art. 33: empresa acima do limite, no ano de
  # início ou valor acima do máximo da faixa.
  # https://www.planalto.gov.br/ccivil_03/leis/lcp/lcp123.htm (conferido em 03/11/2026)
  # https://normas.receita.fazenda.gov.br/sijut2consulta/link.action?idAto=92278 (conferido em 03/11/2026)
  module ValoresFixos
    FONTE = "LC 123/2006, art. 18, §§ 18, 18-A e 22-A; Res. CGSN 140/2018, arts. 33 e 34"

    # Receita do ano anterior até a qual a ME pode ter valor fixo, e a da 1ª faixa (art. 33).
    LIMITE = 36_000_000
    PRIMEIRA_FAIXA = 18_000_000

    # Máximo do valor fixo em cada faixa, em centavos (art. 33, § 2º, I e II).
    MAXIMOS = { "ICMS" => [10_800, 29_550], "ISS" => [16_275, 42_750] }.freeze

    # valores: { "ICMS" => centavos, "ISS" => centavos } (vazio quando não há valor fixo).
    def self.conferir(valores)
      valores = (valores || {}).to_h { |tributo, valor| [tributo.to_s.upcase, valor] }
      valores.each do |tributo, valor|
        raise Entrada::EntradaInvalida, "Valor fixo só existe para o ICMS e o ISS." unless MAXIMOS.key?(tributo)

        Entrada.conferir_valor(valor, "O valor fixo do #{tributo}", positivo: true)
      end
      valores
    end

    # Avisos para conferir (não mudam a conta): o art. 33 não vale para o escritório de
    # contabilidade (art. 34), e a calculadora não sabe se é o caso.
    def self.avisos(dados)
      return [] if dados.valores_fixos.empty?

      [do_ano_anterior(dados), do_ano(dados), do_inicio(dados), *maximos(dados)].compact
    end

    def self.do_ano_anterior(dados)
      return unless dados.receita_ano_anterior.to_i > LIMITE

      "O valor fixo do art. 33 da Res. CGSN 140/2018 é para a ME com receita de até R$ 360.000,00 no ano " \
        "anterior; acima disso, só o escritório de contabilidade paga o ISS em valor fixo (art. 34). Confira " \
        "com o estado ou o município."
    end

    def self.do_ano(dados)
      return unless dados.situacao.receita_ano.to_i > LIMITE

      "A receita do ano passou de R$ 360.000,00: a partir do mês seguinte ao excesso, o ICMS e o ISS voltam " \
        "para o percentual do DAS (Res. CGSN 140/2018, art. 33, § 9º), salvo o escritório de contabilidade."
    end

    def self.do_inicio(dados)
      return unless Sublimite.inicio_no_ano?(dados)

      "No ano de início das atividades, a ME não pode usar o valor fixo do art. 33 (Res. CGSN 140/2018, " \
        "art. 33, § 3º, II), salvo o escritório de contabilidade."
    end

    # O máximo da faixa: o menor se a receita do ano anterior foi até R$ 180.000,00; sem ela, o maior.
    def self.maximos(dados)
      faixa = dados.receita_ano_anterior && dados.receita_ano_anterior <= PRIMEIRA_FAIXA ? 0 : 1
      dados.valores_fixos.filter_map do |tributo, valor|
        maximo = MAXIMOS.fetch(tributo)[faixa]
        next if valor <= maximo

        "O valor fixo do #{tributo} (#{Formato.reais(valor)}) passa do máximo de #{Formato.reais(maximo)} da " \
          "Res. CGSN 140/2018, art. 33, § 2º. Confira o valor na lei do #{tributo == 'ISS' ? 'município' : 'estado'}."
      end
    end

    private_class_method :do_ano_anterior, :do_ano, :do_inicio, :maximos
  end
end
