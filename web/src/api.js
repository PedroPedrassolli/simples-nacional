const MENSAGEM_GENERICA = "Não deu para calcular agora. Tente de novo em instantes.";

// Chama a função da Vercel (api/calcular.rb). Devolve { resultado } ou { erro }, já com
// a mensagem para mostrar. A regra toda fica no Ruby: aqui só se monta a URL.
export async function calcular(parametros) {
  try {
    const resposta = await fetch(`/api/calcular?${new URLSearchParams(parametros)}`);
    const corpo = await resposta.json();
    if (resposta.ok) return { resultado: corpo };
    return { erro: corpo.erro ?? MENSAGEM_GENERICA };
  } catch {
    // Sem internet, função fora do ar ou resposta que não é JSON.
    return { erro: MENSAGEM_GENERICA };
  }
}
