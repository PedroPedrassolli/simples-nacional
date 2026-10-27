const REPOSITORIO = "https://github.com/PedroPedrassolli/simples-nacional";
const PORTFOLIO = "https://pedrassolli.vercel.app";

// Primeira versão da página: explica o que a calculadora vai fazer e deixa os
// avisos no lugar. O formulário e o resultado chegam no card SIMP-6.
export default function App() {
  return (
    <>
      <main className="pagina">
        <p className="selo">Em construção</p>
        <h1>Calculadora do Simples Nacional</h1>
        <p className="destaque">
          Informe a receita bruta dos últimos 12 meses, a receita do mês e o anexo da atividade, e
          veja a alíquota efetiva, o valor estimado do DAS e a conta explicada passo a passo.
        </p>
        <p>
          Quando a atividade pode cair no Anexo III ou no V, a calculadora aplica o Fator R (folha
          de salários dos últimos 12 meses dividida pela receita bruta do mesmo período) e mostra
          por que escolheu um dos anexos.
        </p>

        <section className="aviso" aria-labelledby="aviso-titulo">
          <h2 id="aviso-titulo">Antes de usar</h2>
          <ul>
            <li>
              É uma <strong>estimativa educativa</strong>: não substitui o PGDAS-D nem um contador.
            </li>
            <li>
              A partir de janeiro de 2027, a empresa do Simples pode optar por recolher o IBS e a
              CBS fora do DAS (Lei Complementar 214/2025). Esta calculadora mostra só o DAS do
              regime simplificado.
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
