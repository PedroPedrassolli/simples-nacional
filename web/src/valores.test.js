import { test } from "node:test";
import assert from "node:assert/strict";
import { conferir, dataBrasileira, paraApi } from "./valores.js";

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
    rbt12: "500.000,00",
    receita_mes: "40.000",
    anexo: "3",
    folha12: "",
  });
  assert.deepEqual(erros, {});
  assert.deepEqual(parametros, { anexo: "3", rbt12: "500000.00", receita_mes: "40000.00" });
});

test("pede a folha só no Fator R", () => {
  const { erros } = conferir({ rbt12: "1", receita_mes: "1", anexo: "fator_r", folha12: "" });
  assert.deepEqual(erros, { folha12: "Preencha este campo." });
});

test("aponta o erro de cada campo", () => {
  const { erros } = conferir({ rbt12: "abc", receita_mes: " ", anexo: "", folha12: "" });
  assert.deepEqual(erros, {
    rbt12: "Use só números, como 500.000,00.",
    receita_mes: "Preencha este campo.",
    anexo: "Escolha o anexo.",
  });
});

test("mostra a data no formato brasileiro", () => {
  assert.equal(dataBrasileira("2018-01-01"), "01/01/2018");
});
