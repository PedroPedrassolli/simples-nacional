# frozen_string_literal: true

require "test_helper"

# Receita acima do limite de R$ 4.800.000,00 (LC 123/2006, art. 3º, II, §§ 9º, 9º-A, 10 e 12; art. 18,
# §§ 16 e 16-A; Res. CGSN 140/2018, art. 24, II). Valores fictícios, conferidos com uma implementação
# independente em Python. Anexo III, RBT12 de 4.700.000 (6ª faixa):
#   federais = (4.700.000 × 33% − 648.000) ÷ 4.700.000 = 19,2128%;
#   acima do limite (art. 24, II, a): (4.800.000 × 33% − 648.000) ÷ 4.800.000 = 19,5%.
# Receita do ano de 4.600.000 antes do mês: passou do sublimite em mais de 20% (4.320.000), então o ISS
# já está fora do DAS.
describe SimplesNacional::Limite do
  let(:entrada) { { periodo: "2026-12", anexo: 3, rbt12: 470_000_000, receita_ano: 460_000_000 } }
  let(:receita_mes) { 40_000_000 }

  subject { SimplesNacional.calcular(**entrada, receita_mes:) }

  def passo = subject.passos.find { |item| item.titulo == "Limite do Simples" }

  describe "quando o mês passa do limite em até 20%" do
    # 4.600.000 + 400.000 = 5.000.000: metade do mês acima do limite.
    # 400.000 × (½ × 19,2128% + ½ × 19,5%) = 77.425,53.
    it "usa a alíquota da 6ª faixa com R$ 4.800.000,00 na parte acima" do
      assert_equal [Rational(1, 2), :ano_seguinte], subject.situacao.to_h.values_at(:fracao_limite, :exclusao)
      assert_equal 7_742_553, subject.das
    end

    it "avisa que a empresa sai do Simples no ano seguinte" do
      assert_includes passo.texto, "A parte da receita do mês acima do limite, R$ 200.000,00, paga os tributos federais"
      assert_includes passo.texto, "a empresa sai do Simples em 1º de janeiro de 2027."
      assert_includes SimplesNacional::Avisos.montar(subject), "A receita do ano passou do limite de " \
                                                               "R$ 4.800.000,00: a empresa sai do Simples em 1º de " \
                                                               "janeiro de 2027. Veja o passo a passo."
    end
  end

  describe "quando o mês passa do limite em mais de 20%" do
    let(:receita_mes) { 130_000_000 }

    # 5.900.000 > 5.760.000. 200.000 × 19,2128% + 1.100.000 × 19,5% = 252.925,53.
    it "calcula e avisa a exclusão a partir do mês seguinte" do
      assert_equal [:mes_seguinte, 25_292_553], [subject.situacao.exclusao, subject.das]
      assert_includes passo.texto, "a partir do mês seguinte"
    end
  end

  describe "quando a receita do ano já tinha passado do limite, sem chegar a 20%" do
    # Revenda: (4.800.000 × 19% − 378.000) ÷ 4.800.000 = 11,125% em toda a receita do mês.
    let(:entrada) { { periodo: "2026-12", anexo: 1, rbt12: 530_000_000, receita_ano: 500_000_000 } }
    let(:receita_mes) { 20_000_000 }

    it "usa a alíquota de acima do limite no mês inteiro" do
      assert_equal [1, 2_225_000], [subject.situacao.fracao_limite, subject.das]
      assert_includes passo.texto, "Toda a receita do mês paga os tributos federais"
    end
  end

  describe "em 2027" do
    # Sem percentual maior (art. 24 na redação da Res. CGSN 190/2026): RBT12 de 4.700.000 no Anexo III de
    # 2027: (4.700.000 × 32,9% − 648.000) ÷ 4.700.000 = 19,1128%; 400.000 × 19,1128% = 76.451,06.
    let(:entrada) do
      { periodo: "2027-12", anexo: 3, rbt12: 470_000_000, receita_ano: 460_000_000, receita_mes_anterior: 40_000_000 }
    end

    it "tributa junto com o resto e só avisa a exclusão" do
      assert_equal [0, :ano_seguinte, 7_645_106],
                   [subject.situacao.fracao_limite, subject.situacao.exclusao, subject.das]
      assert_includes passo.texto, "A partir de 2027, a receita acima do limite é tributada junto com o resto"
    end
  end
end
