import { test } from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import {
  conferir,
  dataBrasileira,
  formatarReais,
  MESES_DE_APURACAO,
  mesesDeAtividade,
  mesesDeInicio,
  nomeDoMes,
  paraApi,
  podePassarDoSublimite,
  SUBLIMITE,
  textoSimples,
  textosDosCampos,
} from "./valores.js";

test("converte o jeito brasileiro para o formato da API", () => {
  assert.equal(paraApi("R$ 500.000,00"), "500000.00");
  assert.equal(paraApi("1.234.567,8"), "1234567.80");
  assert.equal(paraApi("40000,5"), "40000.50");
});

test("aceita número sem centavos e pontos de milhar", () => {
  assert.equal(paraApi("500000"), "500000.00");
  assert.equal(paraApi("500.000"), "500000.00");
});

test("aceita ponto como separador de centavos quando não há vírgula", () => {
  assert.equal(paraApi("1234.56"), "1234.56");
});

test("tira zeros à esquerda", () => {
  assert.equal(paraApi("0,50"), "0.50");
  assert.equal(paraApi("007"), "7.00");
});

test("recusa o que não é valor em reais", () => {
  for (const texto of [
    "",
    "abc",
    "-100",
    "1,234,56",
    "500.00,00",
    "1.2345",
    "10,123",
    "12.34.56",
  ]) {
    assert.equal(paraApi(texto), null, texto);
  }
});

test("monta os parâmetros da API quando o formulário está certo", () => {
  const { parametros, erros } = conferir({
    periodo: "2026-03",
    inicio: "",
    rbt12: "500.000,00",
    receita_mes: "40.000",
    anexo: "3",
    folha12: "",
  });
  assert.deepEqual(erros, {});
  assert.deepEqual(parametros, {
    periodo: "2026-03",
    anexo: "3",
    rbt12: "500000.00",
    receita_mes: "40000.00",
  });
});

test("pede a folha só no Fator R", () => {
  const { erros } = conferir({
    periodo: "2026-03",
    rbt12: "1",
    receita_mes: "1",
    anexo: "fator_r",
    folha12: "",
  });
  assert.deepEqual(erros, { folha12: "Preencha este campo." });
});

test("aponta o erro de cada campo", () => {
  const { erros } = conferir({
    periodo: "",
    rbt12: "abc",
    receita_mes: " ",
    anexo: "",
    folha12: "",
  });
  assert.deepEqual(erros, {
    rbt12: "Use só números, como 500.000,00.",
    receita_mes: "Preencha este campo.",
    periodo: "Escolha o mês de apuração.",
    anexo: "Escolha o anexo.",
  });
});

test("no 1º mês de atividade, não pede a receita anterior e manda o início", () => {
  const { parametros, erros } = conferir({
    periodo: "2026-03",
    inicio: "2026-03",
    rbt12: "",
    receita_mes: "20.000",
    anexo: "1",
  });
  assert.deepEqual(erros, {});
  assert.deepEqual(parametros, {
    periodo: "2026-03",
    inicio: "2026-03",
    anexo: "1",
    receita_mes: "20000.00",
  });
});

test("conta os meses de atividade antes do mês de apuração", () => {
  assert.equal(mesesDeAtividade("2026-03", "2025-11"), 4);
  assert.equal(mesesDeAtividade("2026-03", "2026-03"), 0);
  assert.equal(mesesDeAtividade("2026-03", ""), null);
  assert.equal(mesesDeAtividade("", "2026-03"), null);
});

test("lista os meses de início possíveis, do mês de apuração até 11 meses antes", () => {
  const meses = mesesDeInicio("2026-03");
  assert.equal(meses.length, 12);
  assert.deepEqual(
    [meses[0], meses[2], meses[3], meses[11]],
    ["2026-03", "2026-01", "2025-12", "2025-04"],
  );
  assert.deepEqual(mesesDeInicio(""), []);
});

test("escreve os meses por extenso e lista os 12 meses de 2026", () => {
  assert.equal(nomeDoMes("2025-12"), "dezembro de 2025");
  assert.deepEqual([MESES_DE_APURACAO[0], MESES_DE_APURACAO[11]], ["2026-01", "2026-12"]);
});

test("muda os rótulos da receita e da folha no início de atividade", () => {
  assert.equal(
    textosDosCampos("2026-03", "").receita,
    "Receita bruta dos 12 meses anteriores (RBT12)",
  );
  const primeiroMes = textosDosCampos("2026-03", "2026-03");
  assert.deepEqual(
    [primeiroMes.receita, primeiroMes.dicaReceita, primeiroMes.folha],
    [null, null, "Folha de salários do mês"],
  );
  assert.equal(
    textosDosCampos("2026-03", "2025-11").dicaReceita,
    "A soma dos 4 meses antes de março de 2026. A conta tira a média e multiplica por 12.",
  );
  assert.match(textosDosCampos("2026-03", "2026-02").dicaReceita, /^A soma do mês antes de março/);
});

test("mostra a data no formato brasileiro", () => {
  assert.equal(dataBrasileira("2018-01-01"), "01/01/2018");
});

test("descreve a situação no Simples da consulta de CNPJ", () => {
  assert.equal(
    textoSimples({ optante: true, desde: "01/01/2020", excluida_em: null }),
    "Optante pelo Simples Nacional desde 01/01/2020.",
  );
  assert.equal(textoSimples({ optante: true, desde: null }), "Optante pelo Simples Nacional.");
  assert.equal(
    textoSimples({ optante: false, desde: "01/07/2007", excluida_em: "01/07/2007" }),
    "Não consta como optante pelo Simples Nacional (exclusão em 01/07/2007).",
  );
  assert.equal(textoSimples({ optante: false }), "Não consta como optante pelo Simples Nacional.");
});

test("mostra os campos do sublimite só quando fazem sentido", () => {
  assert.deepEqual(
    [textosDosCampos("2026-03", "").receitaAno, textosDosCampos("2026-03", "").receitaAnoAnterior],
    ["Receita bruta de 2026 até o mês anterior", "Receita bruta de 2025"],
  );
  // Janeiro: não há meses antes no ano.
  assert.equal(textosDosCampos("2026-01", "").receitaAno, null);
  // Começou no próprio ano: a receita do ano já é a desde o início, e não há ano anterior.
  assert.deepEqual(
    [
      textosDosCampos("2026-08", "2026-06").receitaAno,
      textosDosCampos("2026-08", "2026-06").receitaAnoAnterior,
    ],
    [null, null],
  );
  assert.equal(textosDosCampos("2026-03", "2025-11").receitaAnoAnterior, "Receita bruta de 2025");
  assert.equal(textosDosCampos("", "").receitaAno, null);
});

test("manda os campos do sublimite só quando preenchidos", () => {
  const base = { periodo: "2026-10", rbt12: "3.900.000", receita_mes: "400.000", anexo: "1" };
  assert.equal(conferir(base).parametros.receita_ano, undefined);
  const { parametros, erros } = conferir({
    ...base,
    receita_ano: "3.300.000",
    receita_ano_anterior: "",
  });
  assert.deepEqual(erros, {});
  assert.equal(parametros.receita_ano, "3300000.00");
  assert.equal(parametros.receita_ano_anterior, undefined);
  assert.deepEqual(conferir({ ...base, receita_ano_anterior: "abc" }).erros, {
    receita_ano_anterior: "Use só números, como 500.000,00.",
  });
  // Em janeiro a receita do ano não vai, mesmo preenchida.
  assert.equal(
    conferir({ ...base, periodo: "2026-01", receita_ano: "1" }).parametros.receita_ano,
    undefined,
  );
});

test("formata o valor do jeito brasileiro ao sair do campo", () => {
  assert.equal(formatarReais("500000"), "500.000,00");
  assert.equal(formatarReais("1234.56"), "1.234,56");
  assert.equal(formatarReais("R$ 4.800.000,5"), "4.800.000,50");
  assert.equal(formatarReais("0,5"), "0,50");
  assert.equal(formatarReais("999"), "999,00");
  // O que não é valor fica como está, para a conferência apontar.
  assert.equal(formatarReais("abc"), "abc");
  assert.equal(formatarReais(""), "");
});

test("formata um texto muito longo sem travar", () => {
  const inicio = Date.now();
  assert.equal(formatarReais("9".repeat(100_000)).length, 133_336);
  assert.ok(Date.now() - inicio < 1000);
});

test("percebe quando a receita do ano pode passar do sublimite", () => {
  const base = { periodo: "2026-10", inicio: "", rbt12: "3.500.000", receita_mes: "100.000" };
  assert.equal(podePassarDoSublimite(base), false);
  assert.equal(podePassarDoSublimite({ ...base, receita_mes: "100.000,01" }), true);
  // Janeiro e quem começou no ano não têm o campo da receita do ano.
  assert.equal(podePassarDoSublimite({ ...base, periodo: "2026-01", rbt12: "9.000.000" }), false);
  assert.equal(podePassarDoSublimite({ ...base, inicio: "2026-02", rbt12: "9.000.000" }), false);
  // Campo em branco ou com erro conta como zero.
  assert.equal(podePassarDoSublimite({ ...base, rbt12: "", receita_mes: "abc" }), false);
});

test("usa o mesmo sublimite do data/sublimite.yml", () => {
  const yaml = fs.readFileSync(new URL("../../data/sublimite.yml", import.meta.url), "utf8");
  const valores = [...yaml.matchAll(/valor: "([\d.]+)"/g)].map((achado) => Number(achado[1]));
  assert.ok(valores.length >= 2);
  for (const valor of valores) assert.equal(valor, SUBLIMITE);
});
