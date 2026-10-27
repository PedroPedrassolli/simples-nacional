// Sem resposta em 15 s (rede ruim, função travada), a página desiste e mostra a mensagem
// de erro, em vez de deixar o botão em "Calculando…" para sempre.
const TEMPO_LIMITE = 15_000;

const ERRO_CALCULO = "Não deu para calcular agora. Tente de novo em instantes.";
const ERRO_CNPJ = "Não deu para consultar o CNPJ agora. Tente de novo em instantes.";

// Chama a função da Vercel (api/calcular.rb). Devolve { resultado } ou { erro }, já com
// a mensagem para mostrar. A regra toda fica no Ruby: aqui só se monta a URL.
export async function calcular(parametros) {
  try {
    const resposta = await fetch(`/api/calcular?${new URLSearchParams(parametros)}`, {
      signal: AbortSignal.timeout(TEMPO_LIMITE),
    });
    const corpo = await resposta.json();
    if (resposta.ok) return { resultado: corpo };
    return { erro: corpo.erro ?? ERRO_CALCULO };
  } catch {
    // Sem internet, tempo limite, função fora do ar ou resposta que não é JSON.
    return { erro: ERRO_CALCULO };
  }
}

// Consulta opcional de CNPJ (api/cnpj.rb). Devolve { empresa } ou { erro }.
export async function consultarCnpj(cnpj) {
  try {
    const resposta = await fetch(`/api/cnpj?${new URLSearchParams({ cnpj })}`, {
      signal: AbortSignal.timeout(TEMPO_LIMITE),
    });
    const corpo = await resposta.json();
    if (resposta.ok) return { empresa: corpo };
    return { erro: corpo.erro ?? ERRO_CNPJ };
  } catch {
    return { erro: ERRO_CNPJ };
  }
}
