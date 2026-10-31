// Funções puras do formulário (sem React), testadas com node --test.

// Converte o valor digitado para o formato que a API espera ("500000.00").
// Aceita "R$ 500.000,00", "500000,5", "500.000" e "1234.56". Devolve null quando o
// texto não é um valor em reais.
export function paraApi(texto) {
  let limpo = String(texto).replace(/R\$/g, "").replace(/\s/g, "");

  if (limpo.includes(",")) {
    // Jeito brasileiro: ponto separa os milhares e vírgula separa os centavos.
    if (!/^(\d{1,3}(\.\d{3})+|\d+),\d{1,2}$/.test(limpo)) return null;
    limpo = limpo.replace(/\./g, "").replace(",", ".");
  } else if (/^\d{1,3}(\.\d{3})+$/.test(limpo)) {
    // "500.000": pontos só como separador de milhar.
    limpo = limpo.replace(/\./g, "");
  }

  if (!/^\d+(\.\d{1,2})?$/.test(limpo)) return null;

  const [reais, centavos = ""] = limpo.split(".");
  return `${reais.replace(/^0+(?=\d)/, "")}.${centavos.padEnd(2, "0")}`;
}

// Ao sair do campo: "500000" → "500.000,00". Texto que não é valor em reais volta como
// está, para a conferência apontar o erro. Os pontos de milhar vão num laço, e não numa
// expressão regular, para não travar com um texto muito longo.
export function formatarReais(texto) {
  const valor = paraApi(texto);
  if (valor === null) return texto;

  const [reais, centavos] = valor.split(".");
  let comPontos = "";
  for (let posicao = 0; posicao < reais.length; posicao++) {
    if (posicao > 0 && (reais.length - posicao) % 3 === 0) comPontos += ".";
    comPontos += reais[posicao];
  }
  return `${comPontos},${centavos}`;
}

// Sublimite do ICMS e do ISS em 2025 e 2026, igual ao data/sublimite.yml (um teste confere).
// Aqui ele só serve para abrir os campos opcionais na hora certa: a regra fica na API.
export const SUBLIMITE = 3_600_000;

// A RBT12 inclui os meses do ano antes do mês de apuração, então RBT12 + receita do mês é
// o máximo que a receita do ano pode ter. Acima do sublimite, a API pede a receita do ano.
export function podePassarDoSublimite({ periodo, inicio, rbt12, receita_mes }) {
  if (!textosDoSublimite(periodo, inicio).receitaAno) return false;
  const soma = Number(paraApi(rbt12 ?? "") ?? 0) + Number(paraApi(receita_mes ?? "") ?? 0);
  return soma > SUBLIMITE;
}

const NOMES_DOS_MESES = [
  "janeiro",
  "fevereiro",
  "março",
  "abril",
  "maio",
  "junho",
  "julho",
  "agosto",
  "setembro",
  "outubro",
  "novembro",
  "dezembro",
];

// "2026-03" → "março de 2026".
export function nomeDoMes(mes) {
  const [ano, numero] = mes.split("-");
  return `${NOMES_DOS_MESES[Number(numero) - 1]} de ${ano}`;
}

// A calculadora aceita só os meses de 2026: as tabelas mudam em 2027 (a API confere).
export const MESES_DE_APURACAO = NOMES_DOS_MESES.map(
  (_, indice) => `2026-${String(indice + 1).padStart(2, "0")}`,
);

// "2026-03" → 2026 × 12 + 3, para contar meses com uma subtração.
const contar = (mes) => {
  const [ano, numero] = mes.split("-").map(Number);
  return ano * 12 + numero;
};

// Meses possíveis de início para quem tem menos de 12 meses de atividade: do mês de
// apuração para trás, até 11 meses antes.
export function mesesDeInicio(periodo) {
  if (!periodo) return [];
  const total = contar(periodo);
  return Array.from({ length: 12 }, (_, atras) => {
    const mes = total - atras - 1;
    return `${Math.floor(mes / 12)}-${String((mes % 12) + 1).padStart(2, "0")}`;
  });
}

// Meses de atividade antes do mês de apuração (0 = começou no próprio mês), ou null
// quando a empresa tem 12 meses ou mais.
export function mesesDeAtividade(periodo, inicio) {
  if (!periodo || !inicio) return null;
  return contar(periodo) - contar(inicio);
}

// Rótulos dos campos que mudam conforme o mês e o início de atividade. receita: null
// quando a receita anterior não é pedida (1º mês: a conta usa a receita do mês × 12).
// receitaAno e receitaAnoAnterior: null quando o campo do sublimite não faz sentido
// (em janeiro não há meses antes no ano; quem começou no ano não tem ano anterior).
export function textosDosCampos(periodo, inicio) {
  return { ...textosDaReceita(periodo, inicio), ...textosDoSublimite(periodo, inicio) };
}

function textosDaReceita(periodo, inicio) {
  const meses = mesesDeAtividade(periodo, inicio);
  if (meses === null) {
    return {
      receita: "Receita bruta dos 12 meses anteriores (RBT12)",
      dicaReceita: "A soma do faturamento dos 12 meses antes do mês de apuração.",
      folha: "Folha de salários dos 12 meses anteriores",
    };
  }
  if (meses === 0) return { receita: null, dicaReceita: null, folha: "Folha de salários do mês" };

  const quantos = meses === 1 ? "do mês" : `dos ${meses} meses`;
  return {
    receita: "Receita bruta desde o início das atividades",
    dicaReceita: `A soma ${quantos} antes de ${nomeDoMes(periodo)}. A conta tira a média e multiplica por 12.`,
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

// Confere o formulário antes de chamar a API. Devolve os parâmetros da URL e os erros
// por campo (vazio quando está tudo certo). A folha só é pedida no Fator R, e a receita
// anterior não é pedida no 1º mês de atividade.
export function conferir(valores) {
  const { periodo, inicio, rbt12, receita_mes, anexo, folha12 } = valores;
  const erros = {};
  const parametros = { periodo, anexo, ...(inicio ? { inicio } : {}) };
  const primeiroMes = mesesDeAtividade(periodo, inicio) === 0;
  const campos = {
    ...(primeiroMes ? {} : { rbt12 }),
    receita_mes,
    ...(anexo === "fator_r" ? { folha12 } : {}),
  };
  // Os campos do sublimite são opcionais: em branco, não vão para a API.
  const textos = textosDoSublimite(periodo, inicio);
  for (const [nome, rotulo] of [
    ["receita_ano", textos.receitaAno],
    ["receita_ano_anterior", textos.receitaAnoAnterior],
  ]) {
    if (rotulo && String(valores[nome] ?? "").trim() !== "") campos[nome] = valores[nome];
  }

  for (const [nome, texto] of Object.entries(campos)) {
    const valor = paraApi(texto);
    if (valor !== null) {
      parametros[nome] = valor;
    } else {
      erros[nome] =
        String(texto).trim() === "" ? "Preencha este campo." : "Use só números, como 500.000,00.";
    }
  }
  if (!periodo) erros.periodo = "Escolha o mês de apuração.";
  if (!anexo) erros.anexo = "Escolha o anexo.";

  return { parametros, erros };
}

// Troca o espaço depois de "R$", "§" e "nº" por um espaço que não quebra: no celular, o
// texto da conta não fica com "R$" no fim de uma linha e o número na outra.
export function semQuebra(texto) {
  return texto.replace(/(R\$|§§?|nº) /g, "$1\u00a0");
}

// "2018-01-01" → "01/01/2018".
export function dataBrasileira(iso) {
  const [ano, mes, dia] = iso.split("-");
  return `${dia}/${mes}/${ano}`;
}

// Frase sobre o Simples na consulta de CNPJ, a partir do que a API devolveu.
export function textoSimples({ optante, desde, excluida_em }) {
  if (optante)
    return desde
      ? `Optante pelo Simples Nacional desde ${desde}.`
      : "Optante pelo Simples Nacional.";
  const exclusao = excluida_em ? ` (exclusão em ${excluida_em})` : "";
  return `Não consta como optante pelo Simples Nacional${exclusao}.`;
}
