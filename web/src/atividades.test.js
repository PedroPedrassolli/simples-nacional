import { test } from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import { dicaDoTipo, opcao, opcoesDoTipo, TIPOS } from "./atividades.js";

// Os códigos do formulário precisam ser os mesmos da API (lib/simples_nacional/atividades.rb).
const RUBY = fs.readFileSync(
  new URL("../../lib/simples_nacional/atividades.rb", import.meta.url),
  "utf8",
);

test("usa os mesmos tipos de receita da API", () => {
  const daApi = [...RUBY.matchAll(/tipo\("(\w+)"/g)].map((achado) => achado[1]);
  // A ordem pode mudar (no formulário, o Fator R vem perto do Anexo III).
  assert.deepEqual(TIPOS.map((tipo) => tipo.valor).toSorted(), daApi.toSorted());
});

test("usa as mesmas situações da API, cada uma com nome e explicação", () => {
  const daApi = [...RUBY.matchAll(/^ {6}"(\w+)" => \[/gm)].map((achado) => achado[1]);
  const doFormulario = [...new Set(TIPOS.flatMap((tipo) => tipo.opcoes))];
  assert.deepEqual(doFormulario.toSorted(), daApi.toSorted());
  for (const codigo of doFormulario) {
    assert.ok(opcao(codigo, 2026).rotulo && opcao(codigo, 2026).dica, codigo);
  }
});

test("o monofásico muda de nome em 2027", () => {
  assert.equal(opcao("monofasico", 2026).rotulo, "PIS/Pasep e Cofins monofásicos");
  assert.match(opcao("monofasico", 2027).rotulo, /^IBS e CBS/);
});

test("o IPI mantido só aparece a partir de 2027", () => {
  assert.deepEqual(opcoesDoTipo("industria", 2026), ["st_icms", "monofasico", "exportacao"]);
  assert.ok(opcoesDoTipo("industria", 2027).includes("ipi_mantido"));
  assert.deepEqual(opcoesDoTipo("locacao", 2027), []);
  assert.deepEqual(opcoesDoTipo("", 2026), []);
});

test("explica o tipo escolhido, ou o que fazer antes de escolher", () => {
  assert.match(dicaDoTipo("locacao"), /sem o ISS/);
  assert.match(dicaDoTipo(""), /informe cada receita separada/);
});
