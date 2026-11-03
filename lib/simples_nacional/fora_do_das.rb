# frozen_string_literal: true

module SimplesNacional
  # Tributos que ficam fora do DAS e que a calculadora estima com dados que a pessoa informa.
  # É uma estimativa: a guia de cada um sai do estado, do município ou da Receita Federal.
  #
  # - ISS e ICMS acima do sublimite: pagos pelas regras normais (LC 123/2006, art. 20, §§ 1º e
  #   1º-A). ISS de 2% a 5% da receita (LC 116/2003, arts. 8º, II, e 8º-A); ICMS pela alíquota
  #   do estado, menos os créditos do mês.
  # - IBS acima do sublimite (2027 em diante) e IBS e CBS de quem optou pelo regime regular
  #   (Res. CGSN 140/2018, arts. 12, 22-A e 40-C, na redação da Res. CGSN 190/2026): alíquota
  #   menos créditos.
  # - CPP do Anexo IV (LC 123/2006, art. 18, § 5º-C): 20% da folha dos empregados mais o RAT
  #   (1%, 2% ou 3%) ajustado pelo FAP (0,5 a 2), e 20% do pró-labore e dos autônomos
  #   (Lei 8.212/1991, art. 22, I a III; Lei 10.666/2003, art. 10).
  # https://www.planalto.gov.br/ccivil_03/leis/lcp/lcp116.htm (conferido em 02/11/2026)
  # https://www.planalto.gov.br/ccivil_03/leis/l8212cons.htm (conferido em 02/11/2026)
  # https://www.planalto.gov.br/ccivil_03/leis/2003/l10.666.htm (conferido em 02/11/2026)
  module ForaDoDas
    # Alíquotas como fração (Rational); dinheiro em centavos; rat: 1, 2 ou 3 (%); fap: Rational.
    Informado = Data.define(:aliquota_iss, :aliquota_icms, :creditos_icms, :aliquota_ibs, :creditos_ibs,
                            :aliquota_cbs, :creditos_cbs, :folha_empregados, :pro_labore, :rat, :fap)

    VAZIO = Informado.new(**Informado.members.to_h { |campo| [campo, nil] })

    # Nomes para as mensagens de erro.
    NOMES = { aliquota_iss: "A alíquota do ISS", aliquota_icms: "A alíquota do ICMS", aliquota_ibs: "A alíquota do IBS",
              aliquota_cbs: "A alíquota da CBS", creditos_icms: "A soma dos créditos de ICMS",
              creditos_ibs: "A soma dos créditos de IBS", creditos_cbs: "A soma dos créditos de CBS",
              folha_empregados: "A folha dos empregados", pro_labore: "A retirada de pró-labore" }.freeze

    ISS_MAXIMO = Rational(5, 100)
    FAP = (Rational(1, 2)..2)

    # valor: em centavos, ou nil quando falta dado (falta diz qual).
    Estimativa = Data.define(:tributo, :base, :valor, :texto, :falta, :fonte)

    def self.conferir(valores)
      valores = (valores || {}).to_h
      sobra = valores.keys - Informado.members
      raise Entrada::EntradaInvalida, "Campo desconhecido fora do DAS: #{sobra.first}." if sobra.any?

      dados = VAZIO.with(**valores)
      conferir_aliquotas(dados)
      conferir_valores(dados)
      conferir_cpp(dados)
      dados
    end

    def self.conferir_aliquotas(dados)
      { aliquota_iss: ISS_MAXIMO, aliquota_icms: 1, aliquota_ibs: 1, aliquota_cbs: 1 }.each do |campo, maximo|
        valor = dados.public_send(campo)
        next if valor.nil? || (valor.is_a?(Rational) && valor.positive? && valor <= maximo)

        raise Entrada::EntradaInvalida, "#{NOMES.fetch(campo)} precisa ser maior que zero e no máximo " \
                                        "#{Formato.percentual(maximo)}."
      end
    end

    def self.conferir_valores(dados)
      %i[creditos_icms creditos_ibs creditos_cbs folha_empregados pro_labore].each do |campo|
        valor = dados.public_send(campo)
        Entrada.conferir_valor(valor, NOMES.fetch(campo)) unless valor.nil?
      end
    end

    def self.conferir_cpp(dados)
      raise Entrada::EntradaInvalida, "O RAT precisa ser 1, 2 ou 3 (%)." unless [nil, 1, 2, 3].include?(dados.rat)
      return if dados.fap.nil? || (dados.fap.is_a?(Rational) && FAP.cover?(dados.fap))

      raise Entrada::EntradaInvalida, "O FAP precisa estar entre 0,5 e 2,0 (Lei 10.666/2003, art. 10)."
    end

    # As estimativas que fazem sentido para o mês, na ordem em que a página mostra.
    # apuradas: as atividades já calculadas (ver ApuracaoDaAtividade), com a tabela de cada uma.
    def self.estimar(dados, apuradas)
      informado = dados.fora_do_das
      local_fora = dados.situacao.local == :fora
      [(Locais.iss(apuradas, informado) if local_fora),
       (Locais.icms(apuradas, informado) if local_fora),
       (Locais.ibs(apuradas, informado) if local_fora || dados.ibs_cbs_fora),
       (Locais.cbs(apuradas, informado) if dados.ibs_cbs_fora),
       Cpp.estimar(apuradas, informado)].compact
    end

    # Soma das receitas das atividades que pagariam o tributo no DAS (antes do sublimite e
    # da opção): o anexo tem o tributo e nenhum qualificador o tirou.
    def self.base(apuradas, tributo)
      apuradas.sum do |apurada|
        tem = apurada.tabela.faixas.first.reparticao.key?(tributo) ||
              (tributo == "ICMS" && apurada.atividade.tipo.icms_do_anexo_i)
        tem && !apurada.tirados.include?(tributo) ? apurada.atividade.receita : 0
      end
    end

    private_class_method :conferir_aliquotas, :conferir_valores, :conferir_cpp
  end
end
