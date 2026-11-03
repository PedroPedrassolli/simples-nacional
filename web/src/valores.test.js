import { test } from "node:test";
import assert from "node:assert/strict";
import {
  dataBrasileira,
  formatarReais,
  mesCurto,
  nomeDoMes,
  paraApi,
  paraPercentual,
  reais,
  semQuebra,
  textoSimples,
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

test("escreve centavos como reais, sem quebra depois do R$", () => {
  assert.equal(reais(123456), "R$\u00a01.234,56");
  assert.equal(reais(0), "R$\u00a00,00");
  assert.equal(reais(5), "R$\u00a00,05");
});

test("converte o percentual digitado para o formato da API", () => {
  assert.equal(paraPercentual("3,5"), "3.5");
  assert.equal(paraPercentual("3.5%"), "3.5");
  assert.equal(paraPercentual(" 18 "), "18");
  assert.equal(paraPercentual("05"), "5");
  assert.equal(paraPercentual("0,6575"), "0.6575");
});

test("recusa percentual que não é número", () => {
  for (const texto of ["", "abc", "-2", "1,2,3", "1000", "2,12345"]) {
    assert.equal(paraPercentual(texto), null, texto);
  }
});

test("escreve os meses por extenso e abreviados", () => {
  assert.equal(nomeDoMes("2025-12"), "dezembro de 2025");
  assert.equal(nomeDoMes("2027-03"), "março de 2027");
  assert.equal(mesCurto("2026-02"), "fev/2026");
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

test("não deixa a linha quebrar depois de R$, § e nº", () => {
  assert.equal(
    semQuebra("R$ 3.600.000,00 (art. 18, § 1º; §§ 24 e 26; Portaria nº 54)"),
    "R$ 3.600.000,00 (art. 18, § 1º; §§ 24 e 26; Portaria nº 54)",
  );
  assert.equal(semQuebra("sem nada"), "sem nada");
});
