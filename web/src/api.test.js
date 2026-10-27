import { test } from "node:test";
import assert from "node:assert/strict";
import { calcular, consultarCnpj } from "./api.js";

// Simula uma função que nunca responde: o fetch só termina quando o sinal de tempo
// limite dispara. O AbortSignal.timeout de verdade levaria 15 s; aqui ele já vem
// disparado, e o teste confere que a página pediu 15 s.
function semResposta(t) {
  const pedidos = [];
  t.mock.method(AbortSignal, "timeout", (ms) => {
    pedidos.push(ms);
    return AbortSignal.abort(new DOMException("Tempo esgotado", "TimeoutError"));
  });
  t.mock.method(globalThis, "fetch", (_url, { signal }) => Promise.reject(signal.reason));
  return pedidos;
}

test("desiste do cálculo depois de 15 s e mostra a mensagem de erro", async (t) => {
  const pedidos = semResposta(t);
  const resposta = await calcular({ anexo: "3", rbt12: "500000.00", receita_mes: "40000.00" });

  assert.deepEqual(resposta, {
    erro: "Não deu para calcular agora. Tente de novo em instantes.",
  });
  assert.deepEqual(pedidos, [15_000]);
});

test("desiste da consulta de CNPJ depois de 15 s com a mensagem certa", async (t) => {
  const pedidos = semResposta(t);
  const resposta = await consultarCnpj("11.222.333/0001-81");

  assert.deepEqual(resposta, {
    erro: "Não deu para consultar o CNPJ agora. Tente de novo em instantes.",
  });
  assert.deepEqual(pedidos, [15_000]);
});

test("repassa a mensagem de erro que a API mandou", async (t) => {
  t.mock.method(globalThis, "fetch", async () =>
    Response.json({ erro: "CNPJ inválido: confira os números." }, { status: 400 }),
  );

  assert.deepEqual(await consultarCnpj("11.222.333/0001-80"), {
    erro: "CNPJ inválido: confira os números.",
  });
});
