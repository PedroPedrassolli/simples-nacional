# frozen_string_literal: true

require "test_helper"

# O limite extra da exportação (LC 123/2006, art. 3º, §§ 14 e 15; Res. CGSN 140/2018, art. 24,
# § 8º). R$ 200.000,00 de exportação em outubro, com RBT12 de exportação de R$ 4.700.000,00.
# Contas feitas à parte, com frações: sem limite, 7,18809% (6ª faixa do Anexo I sem Cofins,
# PIS/Pasep e locais); metade acima do limite, pela 6ª faixa com R$ 4.800.000,00.
describe SimplesNacional::LimiteDaExportacao do
  let(:periodo) { "2026-10" }
  let(:extras) { {} }

  def exportacao(receita) = { tipo: "revenda", receita:, opcoes: ["exportacao"] }

  subject do
    SimplesNacional.calcular(periodo:, rbt12: 100_000_000, rbt12_exportacao: 470_000_000,
                             atividades: [exportacao(20_000_000)], **extras)
  end

  describe "sem a receita de exportação do ano" do
    it "calcula sem o limite e avisa que pode passar dele" do
      assert_equal 1_437_617, subject.das
      assert_match(/informe a receita de exportação do ano/, SimplesNacional::Avisos.montar(subject).join)
    end

    it "diz no passo que não conferiu o limite" do
      passo = subject.passos.find { |item| item.titulo == "Exportação" }
      assert_match(/não confere esse limite/, passo.texto)
    end
  end

  describe "acima do limite em 2026" do
    let(:extras) { { receita_ano_exportacao: 470_000_000 } }

    it "cobra a parte acima do limite pela 6ª faixa e marca a exclusão para o ano seguinte" do
      situacao = subject.dados.situacao_exportacao
      assert_equal [1_448_609, Rational(1, 2), :ano_seguinte], [subject.das, situacao.fracao_limite, situacao.exclusao]
    end

    it "explica no passo e avisa no topo" do
      passo = subject.passos.find { |item| item.titulo == "Exportação" }
      assert_match(/A parte da exportação do mês acima do limite, R\$ 100\.000,00/, passo.texto)
      assert_match(/limite extra de R\$ 4\.800\.000,00: a empresa sai do Simples em 1º de janeiro de 2027/,
                   SimplesNacional::Avisos.montar(subject).join)
    end
  end

  describe "acima do limite com excesso de mais de 20%" do
    let(:extras) { { receita_ano_exportacao: 560_000_000 } }

    it "marca a exclusão para o mês seguinte" do
      assert_equal :mes_seguinte, subject.dados.situacao_exportacao.exclusao
    end
  end

  describe "dentro do limite" do
    let(:extras) { { receita_ano_exportacao: 300_000_000 } }

    it "calcula sem mudança e diz que está dentro" do
      assert_equal 1_437_617, subject.das
      assert_match(/soma R\$ 3\.200\.000,00, dentro do limite/, subject.passos.find do |item|
        item.titulo == "Exportação"
      end.texto)
    end
  end

  describe "a partir de 2027" do
    let(:periodo) { "2027-10" }
    let(:extras) { { receita_ano_exportacao: 470_000_000, receita_mes_anterior: 0 } }

    it "não tem percentual maior, só a exclusão" do
      situacao = subject.dados.situacao_exportacao
      assert_equal [0, :ano_seguinte], [situacao.fracao_limite, situacao.exclusao]
      assert_match(/A partir de 2027, a receita acima do limite é tributada junto com o resto/,
                   subject.passos.find { |item| item.titulo == "Exportação" }.texto)
    end
  end

  describe "já fora do Simples pela exportação" do
    let(:extras) { { receita_ano_exportacao: 580_000_000 } }

    it "recusa e explica" do
      erro = assert_raises(SimplesNacional::Entrada::EntradaInvalida) { subject }
      assert_match(/receita de exportação de 2026 passa de R\$ 5\.760\.000,00/, erro.message)
    end
  end

  describe "em janeiro e no ano de início" do
    it "considera zero em janeiro" do
      situacao = SimplesNacional.calcular(periodo: "2026-01", rbt12: 100_000, rbt12_exportacao: 100_000,
                                          atividades: [exportacao(1_000)])
                                .dados.situacao_exportacao
      assert_equal 0, situacao.receita_ano
    end

    # Início em julho: limite de R$ 2.400.000,00; desde o início, R$ 2.500.000,00 de exportação.
    it "usa a receita desde o início e o limite proporcional em 2026" do
      resultado = SimplesNacional.calcular(periodo: "2026-10", inicio: "2026-07", rbt12: 100_000,
                                           rbt12_exportacao: 230_000_000, atividades: [exportacao(20_000_000)])
      situacao = resultado.dados.situacao_exportacao
      assert_equal [240_000_000, 230_000_000, :ano_seguinte], [situacao.limite, situacao.receita_ano, situacao.exclusao]
      assert_match(/no ano de início/, resultado.passos.find { |item| item.titulo == "Exportação" }.texto)
    end

    it "recusa no ano de início com excesso de mais de 20%" do
      assert_raises(SimplesNacional::Entrada::EntradaInvalida) do
        SimplesNacional.calcular(periodo: "2026-10", inicio: "2026-07", rbt12: 100_000, rbt12_exportacao: 280_000_000,
                                 atividades: [exportacao(20_000_000)])
      end
    end
  end

  describe "no mês a mês" do
    it "soma a exportação dos meses do ano" do
      historico = (1..12).to_h do |numero|
        mes = Date.new(2025, 10, 1).next_month(numero - 1)
        [mes.strftime("%Y-%m"), { receita: 100_000, exportacao: mes.year == 2026 ? 50_000_000 : 0 }]
      end
      resultado = SimplesNacional.calcular(periodo: "2026-10", historico:,
                                           atividades: [exportacao(1_000)])
      assert_equal 450_000_000, resultado.dados.situacao_exportacao.receita_ano
    end
  end
end
