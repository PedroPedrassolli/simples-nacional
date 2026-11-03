// Funções puras de texto e número (sem React), testadas com node --test.

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

// Centavos (número) → "R$ 1.234,56", para os totais que a página soma sozinha. O espaço
// depois do "R$" não quebra (\u00a0), como em semQuebra.
export function reais(centavos) {
  const texto = (centavos / 100).toFixed(2).replace(".", ",");
  return `R$\u00a0${formatarReais(texto)}`;
}

// Percentual digitado ("3,5", "3.5%", "18") → "3.5", como a API espera. null se não for um
// percentual com até 3 dígitos e 4 casas.
export function paraPercentual(texto) {
  const limpo = String(texto).replace(/%/g, "").replace(/\s/g, "").replace(",", ".");
  return /^\d{1,3}(\.\d{1,4})?$/.test(limpo) ? limpo.replace(/^0+(?=\d)/, "") : null;
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

// "2026-03" → "mar/2026", para as linhas da tabela do mês a mês.
export function mesCurto(mes) {
  const [ano, numero] = mes.split("-");
  return `${NOMES_DOS_MESES[Number(numero) - 1].slice(0, 3)}/${ano}`;
}

// Troca o espaço depois de "R$", "§" e "nº" por um espaço que não quebra: no celular, o
// texto da conta não fica com "R$" no fim de uma linha e o número na outra.
export function semQuebra(texto) {
  return texto.replace(/(R\$|§§?|nº) /g, "$1 ");
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
