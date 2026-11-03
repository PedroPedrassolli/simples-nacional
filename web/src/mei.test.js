import { test } from "node:test";
import assert from "node:assert/strict";
import { MEI_VAZIO, VAZIO } from "./formulario.js";
import { ATIVIDADES_DO_MEI, conferirMei, iniciosDoMei, linhasDaMemoriaDoMei } from "./mei.js";
import fs from "node:fs";

// Um MEI preenchido, com o que cada teste mudar por cima.
function formulario(mei = {}, mudancas = {}) {
  return {
    ...VAZIO,
    regime: "mei",
    periodo: "2026-03",
    mei: { ...MEI_VAZIO, atividade: "comercio", ...mei },
    ...mudancas,
  };
}

test("monta os parâmetros do MEI", () => {
  const { parametros, erros } = conferirMei(formulario());
  assert.deepEqual(erros, {});
  assert.deepEqual(parametros, { periodo: "2026-03", regime: "mei", mei_atividade: "comercio" });
});

test("manda o transportador, o início, a receita do ano, o salário mínimo e o pagamento", () => {
  const valores = formulario(
    {
      transportador: true,
      inicio: "2026-02",
      receita_ano: "90.000",
      salario_minimo: "1.700,00",
    },
    { pagamento: "2026-04-21" },
  );
  assert.deepEqual(conferirMei(valores).parametros, {
    periodo: "2026-03",
    regime: "mei",
    mei_atividade: "comercio",
    transportador: "1",
    inicio: "2026-02",
    receita_ano: "90000.00",
    salario_minimo: "1700.00",
    pagamento: "2026-04-21",
  });
});

test("aponta o que falta ou está em formato errado", () => {
  const { erros } = conferirMei(formulario({ atividade: "", receita_ano: "abc" }, { periodo: "" }));
  assert.deepEqual(erros, {
    periodo: "Escolha o mês e o ano de apuração.",
    "mei.atividade": "Escolha a atividade do MEI.",
    "mei.receita_ano": "Use só números, como 500.000,00.",
  });
});

test("ignora o início que ficou fora do ano depois de trocar o mês", () => {
  assert.equal(conferirMei(formulario({ inicio: "2025-12" })).parametros.inicio, undefined);
});

test("lista os meses de início do ano, do mais novo ao mais antigo", () => {
  assert.deepEqual(iniciosDoMei("2026-03"), ["2026-03", "2026-02", "2026-01"]);
  assert.deepEqual(iniciosDoMei(""), []);
});

test("usa as mesmas atividades da API", () => {
  const ruby = fs.readFileSync(
    new URL("../../lib/simples_nacional/mei.rb", import.meta.url),
    "utf8",
  );
  const daApi = [...ruby.matchAll(/^ {6}"(\w+)" => Atividade/gm)].map((achado) => achado[1]);
  assert.deepEqual(ATIVIDADES_DO_MEI.map((item) => item.valor).toSorted(), daApi.toSorted());
});

test("lista os dados do MEI para a memória de cálculo", () => {
  const valores = formulario(
    { atividade: "servicos", transportador: true, inicio: "2026-02", receita_ano: "90000" },
    { pagamento: "2026-05-04" },
  );
  assert.deepEqual(linhasDaMemoriaDoMei(valores), [
    ["Mês de apuração", "março de 2026"],
    ["Atividade", "Serviços"],
    ["Transportador autônomo de cargas", "sim"],
    ["Início das atividades", "fevereiro de 2026"],
    ["Receita bruta de 2026", "R$ 90.000,00"],
    ["Data do pagamento", "04/05/2026"],
  ]);
});
