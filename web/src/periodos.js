// Os meses do formulário e o que muda de um ano para o outro. A regra fica na API
// (lib/simples_nacional/regras.rb); aqui só os textos e quais campos mostrar.
import { nomeDoMes, paraApi } from "./valores.js";

// A calculadora aceita meses de 2026 a 2028 (em 2029 as tabelas mudam: LC 214/2025).
export const ANOS = [2026, 2027, 2028];

export const MESES_DE_APURACAO = ANOS.flatMap((ano) =>
  Array.from({ length: 12 }, (_, indice) => `${ano}-${String(indice + 1).padStart(2, "0")}`),
);

// Sublimite do ICMS, do ISS e (a partir de 2027) do IBS, igual ao data/sublimite.yml (um
// teste confere). Aqui ele só serve para abrir os campos opcionais na hora certa.
export const SUBLIMITE = 3_600_000;

// A RBT12 (mais o mês anterior, a partir de 2027) e as receitas do mês são o máximo que a
// receita do ano pode ter: acima do sublimite, a API pede a receita do ano. No mês a mês a
// receita do ano sai da tabela, então não há o que abrir.
export function podePassarDoSublimite(valores) {
  if (valores.modo === "meses" || !textosDosCampos(valores.periodo, valores.inicio).receitaAno)
    return false;
  const numero = (texto) => Number(paraApi(texto ?? "") ?? 0);
  const doMes = valores.receitas.reduce((total, receita) => total + numero(receita.valor), 0);
  return numero(valores.rbt12) + numero(valores.receita_mes_anterior) + doMes > SUBLIMITE;
}

// "2026-03" → 2026 × 12 + 3, para contar meses com uma subtração.
const contar = (mes) => {
  const [ano, numero] = mes.split("-").map(Number);
  return ano * 12 + numero;
};

// O mês "quantos" meses antes de "mes": mesAntes("2026-03", 2) → "2026-01".
export function mesAntes(mes, quantos) {
  const total = contar(mes) - quantos - 1;
  return `${Math.floor(total / 12)}-${String((total % 12) + 1).padStart(2, "0")}`;
}

// A partir de 2027 a RBT12 pula o mês anterior, o início de atividade usa a 1ª faixa nos
// dois primeiros meses e o IBS e a CBS podem ficar fora do DAS (Res. CGSN 190/2026).
export function regrasDoAno(periodo) {
  const ano = Number(String(periodo).slice(0, 4));
  const novas = ano >= 2027;
  return { ano, novas, mesesDaJanela: novas ? 13 : 12 };
}

// Meses possíveis de início para quem ainda está no início de atividade: do mês de
// apuração para trás (11 meses antes em 2026, 12 a partir de 2027).
export function mesesDeInicio(periodo) {
  if (!periodo) return [];
  const { mesesDaJanela } = regrasDoAno(periodo);
  return Array.from({ length: mesesDaJanela }, (_, atras) => mesAntes(periodo, atras));
}

// Meses de atividade antes do mês de apuração (0 = começou no próprio mês), ou null
// quando a empresa já tem a RBT12 normal.
export function mesesDeAtividade(periodo, inicio) {
  if (!periodo || !inicio) return null;
  return contar(periodo) - contar(inicio);
}

// Os meses da tabela do mês a mês: a janela da RBT12 e os meses do ano, do mais antigo
// ao mais novo, sem os anteriores ao início.
export function mesesDoHistorico(periodo, inicio) {
  if (!periodo) return [];
  const { mesesDaJanela } = regrasDoAno(periodo);
  // Do mais antigo (mesesDaJanela meses antes) até o mês anterior (1 mês antes).
  const meses = Array.from({ length: mesesDaJanela }, (_, posicao) =>
    mesAntes(periodo, mesesDaJanela - posicao),
  );
  return inicio ? meses.filter((mes) => mes >= inicio) : meses;
}

// Rótulos e quais campos mostrar, conforme o mês e o início de atividade.
// receita: null quando a RBT12 não é pedida (1º mês em 2026; 1º e 2º mês a partir de 2027).
// mesAnterior: rótulo da receita do mês anterior (só a partir de 2027), ou null.
// receitaAno e receitaAnoAnterior: null quando o campo do sublimite não faz sentido.
export function textosDosCampos(periodo, inicio) {
  return {
    ...textosDaReceita(periodo, inicio),
    ...textosDoSublimite(periodo, inicio),
    mesAnterior: textoDoMesAnterior(periodo, inicio),
  };
}

function textosDaReceita(periodo, inicio) {
  const meses = mesesDeAtividade(periodo, inicio);
  const { novas } = regrasDoAno(periodo);
  if (meses === null) {
    return novas
      ? {
          receita: "Receita bruta dos 12 meses antes do mês anterior (RBT12)",
          dicaReceita: periodo
            ? `A partir de 2027, a RBT12 vai de ${nomeDoMes(mesAntes(periodo, 13))} a ${nomeDoMes(mesAntes(periodo, 2))}.`
            : "A partir de 2027, a RBT12 pula o mês anterior ao de apuração.",
          folha: "Folha de salários dos mesmos 12 meses",
        }
      : {
          receita: "Receita bruta dos 12 meses anteriores (RBT12)",
          dicaReceita: "A soma do faturamento dos 12 meses antes do mês de apuração.",
          folha: "Folha de salários dos 12 meses anteriores",
        };
  }
  if (novas ? meses < 2 : meses === 0) {
    return { receita: null, dicaReceita: null, folha: novas ? null : "Folha de salários do mês" };
  }

  const divisor = novas ? meses - 1 : meses;
  const quantos = divisor === 1 ? "do mês" : `dos ${divisor} meses`;
  const ate = novas ? mesAntes(periodo, 1) : periodo;
  return {
    receita: "Receita bruta desde o início das atividades",
    dicaReceita: `A soma ${quantos} antes de ${nomeDoMes(ate)}. A conta tira a média e multiplica por 12.`,
    folha: "Folha de salários desde o início das atividades",
  };
}

function textosDoSublimite(periodo, inicio) {
  if (!periodo) return { receitaAno: null, receitaAnoAnterior: null };
  const [ano, mes] = periodo.split("-").map(Number);
  const comecouNoAno = Boolean(inicio) && Number(inicio.slice(0, 4)) === ano;
  return {
    receitaAno: mes > 1 && !comecouNoAno ? `Receita bruta de ${ano} até o mês anterior` : null,
    receitaAnoAnterior: comecouNoAno ? null : `Receita bruta de ${ano - 1}`,
  };
}

// A partir de 2027 a RBT12 não tem o mês anterior: ele é pedido à parte (para a receita do
// ano e o sublimite), menos em janeiro e no 1º mês de atividade.
function textoDoMesAnterior(periodo, inicio) {
  if (!periodo || !regrasDoAno(periodo).novas || periodo.endsWith("-01")) return null;
  if (mesesDeAtividade(periodo, inicio) === 0) return null;
  return `Receita bruta de ${nomeDoMes(mesAntes(periodo, 1))}`;
}
