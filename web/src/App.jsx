import Calculadora from "./Calculadora.jsx";

const REPOSITORIO = "https://github.com/PedroPedrassolli/simples-nacional";
const PORTFOLIO = "https://pedrassolli.vercel.app";

// A página inteira. No build ela vira HTML pronto (scripts/prerender.mjs), e o React só
// assume os eventos no navegador: o texto aparece antes do JavaScript e nada pula de lugar.
export default function App() {
  return (
    <>
      <header className="topo">
        <h1>Calculadora do Simples Nacional</h1>
        <p className="destaque">
          Informe a receita bruta dos 12 meses anteriores, a receita do mês e o anexo da atividade,
          e veja a alíquota efetiva, o valor estimado do DAS e a conta explicada passo a passo.
        </p>
      </header>

      <main className="pagina">
        <Calculadora />

        <section className="aviso" aria-labelledby="aviso-titulo">
          <h2 id="aviso-titulo">Antes de usar</h2>
          <ul>
            <li>
              É uma <strong>estimativa educativa</strong>: não substitui o PGDAS-D nem um contador.
            </li>
            <li>
              Quando a atividade pode cair no Anexo III ou no V, a calculadora aplica o Fator R
              (folha de salários ÷ receita bruta, ambas dos 12 meses anteriores): com 28% ou mais,
              Anexo III; abaixo disso, Anexo V.
            </li>
            <li>
              A partir de janeiro de 2027, a empresa do Simples pode optar por recolher o IBS e a
              CBS fora do DAS (Lei Complementar 214/2025). Esta calculadora mostra só o DAS do
              regime simplificado.
            </li>
            <li>
              Ainda não trata empresa com menos de 12 meses de atividade, sublimites estaduais nem a
              divisão do DAS entre os tributos.
            </li>
          </ul>
        </section>
      </main>

      <footer className="rodape">
        <p>
          Código aberto no <a href={REPOSITORIO}>GitHub</a>, com as tabelas e a fonte oficial de
          cada uma. Feito por <a href={PORTFOLIO}>Pedro Pedrassolli</a>.
        </p>
      </footer>
    </>
  );
}
