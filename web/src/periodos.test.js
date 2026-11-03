import { test } from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import {
  ANOS,
  MESES_DE_APURACAO,
  mesAntes,
  mesesDeAtividade,
  mesesDeInicio,
  mesesDoHistorico,
  podePassarDoSublimite,
  regrasDoAno,
  SUBLIMITE,
  textosDosCampos,
} from "./periodos.js";
import { novaReceita, VAZIO } from "./formulario.js";

test("lista os meses de 2026 a 2028", () => {
  assert.deepEqual(ANOS, [2026, 2027, 2028]);
  assert.equal(MESES_DE_APURACAO.length, 36);
  assert.deepEqual([MESES_DE_APURACAO[0], MESES_DE_APURACAO[35]], ["2026-01", "2028-12"]);
});

test("volta meses, inclusive de um ano para o outro", () => {
  assert.equal(mesAntes("2026-03", 0), "2026-03");
  assert.equal(mesAntes("2026-03", 2), "2026-01");
  assert.equal(mesAntes("2026-03", 3), "2025-12");
  assert.equal(mesAntes("2027-01", 13), "2025-12");
});

test("sabe quando valem as regras de 2027", () => {
  assert.deepEqual(regrasDoAno("2026-12"), { ano: 2026, novas: false, mesesDaJanela: 12 });
  assert.deepEqual(regrasDoAno("2028-01"), { ano: 2028, novas: true, mesesDaJanela: 13 });
});

test("conta os meses de atividade antes do mês de apuração", () => {
  assert.equal(mesesDeAtividade("2026-03", "2025-11"), 4);
  assert.equal(mesesDeAtividade("2026-03", "2026-03"), 0);
  assert.equal(mesesDeAtividade("2026-03", ""), null);
  assert.equal(mesesDeAtividade("", "2026-03"), null);
});

test("lista os meses de início possíveis: 12 em 2026 e 13 a partir de 2027", () => {
  const meses = mesesDeInicio("2026-03");
  assert.equal(meses.length, 12);
  assert.deepEqual([meses[0], meses[3], meses[11]], ["2026-03", "2025-12", "2025-04"]);
  assert.equal(mesesDeInicio("2027-03").at(-1), "2026-03");
  assert.deepEqual(mesesDeInicio(""), []);
});

test("lista os meses do mês a mês, do mais antigo ao mais novo", () => {
  const meses = mesesDoHistorico("2026-03");
  assert.deepEqual([meses.length, meses[0], meses[11]], [12, "2025-03", "2026-02"]);
  // A partir de 2027: os 12 da RBT12 e o mês anterior.
  const novos = mesesDoHistorico("2027-03");
  assert.deepEqual([novos.length, novos[0], novos[12]], [13, "2026-02", "2027-02"]);
  // Sem os meses antes do início.
  assert.deepEqual(mesesDoHistorico("2026-03", "2026-01"), ["2026-01", "2026-02"]);
  assert.deepEqual(mesesDoHistorico(""), []);
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

test("a partir de 2027, a RBT12 pula o mês anterior e os 2 primeiros meses não pedem receita", () => {
  assert.equal(
    textosDosCampos("2027-03", "").dicaReceita,
    "A partir de 2027, a RBT12 vai de fevereiro de 2026 a janeiro de 2027.",
  );
  assert.equal(textosDosCampos("2027-03", "2027-02").receita, null);
  assert.equal(textosDosCampos("2027-03", "2027-02").folha, null);
  assert.equal(
    textosDosCampos("2027-03", "2026-12").dicaReceita,
    "A soma dos 2 meses antes de fevereiro de 2027. A conta tira a média e multiplica por 12.",
  );
});

test("pede a receita do mês anterior só a partir de 2027, fora de janeiro e do 1º mês", () => {
  assert.equal(textosDosCampos("2026-03", "").mesAnterior, null);
  assert.equal(textosDosCampos("2027-03", "").mesAnterior, "Receita bruta de fevereiro de 2027");
  assert.equal(textosDosCampos("2027-01", "").mesAnterior, null);
  assert.equal(textosDosCampos("2027-03", "2027-03").mesAnterior, null);
});

test("mostra os campos do sublimite só quando fazem sentido", () => {
  assert.deepEqual(
    [textosDosCampos("2026-03", "").receitaAno, textosDosCampos("2026-03", "").receitaAnoAnterior],
    ["Receita bruta de 2026 até o mês anterior", "Receita bruta de 2025"],
  );
  // Janeiro: não há meses antes no ano.
  assert.equal(textosDosCampos("2026-01", "").receitaAno, null);
  // Começou no próprio ano: não há receita do ano anterior.
  const noAno = textosDosCampos("2026-08", "2026-06");
  assert.deepEqual([noAno.receitaAno, noAno.receitaAnoAnterior], [null, null]);
  assert.equal(textosDosCampos("", "").receitaAno, null);
});

test("percebe quando a receita do ano pode passar do sublimite", () => {
  const base = {
    ...VAZIO,
    periodo: "2026-10",
    rbt12: "3.500.000",
    receitas: [novaReceita(1, "revenda", "60.000"), novaReceita(2, "servicos_3", "40.000")],
  };
  assert.equal(podePassarDoSublimite(base), false);
  assert.equal(
    podePassarDoSublimite({ ...base, receitas: [novaReceita(1, "revenda", "100.000,01")] }),
    true,
  );
  // A partir de 2027 o mês anterior também conta.
  assert.equal(
    podePassarDoSublimite({ ...base, periodo: "2027-10", receita_mes_anterior: "1" }),
    true,
  );
  // Janeiro, início no ano e mês a mês não têm o campo da receita do ano.
  assert.equal(podePassarDoSublimite({ ...base, periodo: "2026-01", rbt12: "9.000.000" }), false);
  assert.equal(podePassarDoSublimite({ ...base, inicio: "2026-02", rbt12: "9.000.000" }), false);
  assert.equal(podePassarDoSublimite({ ...base, modo: "meses", rbt12: "9.000.000" }), false);
});

test("conta campo em branco ou com erro como zero", () => {
  const valores = {
    ...VAZIO,
    periodo: "2026-10",
    rbt12: "",
    receitas: [novaReceita(1, "revenda", "abc")],
  };
  assert.equal(podePassarDoSublimite(valores), false);
});

test("usa o mesmo sublimite do data/sublimite.yml", () => {
  const yaml = fs.readFileSync(new URL("../../data/sublimite.yml", import.meta.url), "utf8");
  const valores = [...yaml.matchAll(/valor: "([\d.]+)"/g)].map((achado) => Number(achado[1]));
  assert.ok(valores.length >= 4);
  for (const valor of valores) assert.equal(valor, SUBLIMITE);
});
