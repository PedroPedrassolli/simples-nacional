import Calculadora from "./Calculadora.jsx";
import ConsultaCnpj from "./ConsultaCnpj.jsx";

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
          Estimativa educativa do DAS para meses de 2026. Informe a receita e o anexo da atividade e
          veja a alíquota efetiva, quanto vai para cada tributo e a conta explicada passo a passo,
          com a base legal.
        </p>
      </header>

      <main className="pagina">
        {/* No computador, formulário e consulta de CNPJ à esquerda, resultado à direita; no
            celular, tudo em uma coluna. Os avisos ficam embaixo, em largura total. */}
        <Calculadora consulta={<ConsultaCnpj />} />
        <Aviso />
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

function Aviso() {
  return (
    <section className="aviso" aria-labelledby="aviso-titulo">
      <h2 id="aviso-titulo">Antes de usar</h2>
      <ul>
        <li>
          É uma <strong>estimativa educativa</strong>: não substitui o PGDAS-D nem um contador.
        </li>
        <li>
          Calcula só meses de 2026. Em 2027 as tabelas mudam (LC 214/2025), e a empresa pode optar
          por recolher o IBS e a CBS fora do DAS.
        </li>
        <li>
          Considera uma atividade só. Se a empresa tem receitas de anexos diferentes, cada uma é
          tributada pelo seu anexo (LC 123/2006, art. 18, § 4º), e a calculadora não junta as
          partes.
        </li>
        <li>
          Não cobre receita acima de R$ 4.800.000,00 no ano (a empresa sai do Simples) nem tira a
          parcela do ISS da locação de bens móveis.
        </li>
        <li>
          Quando o ICMS ou o ISS sai do DAS pelo sublimite, a calculadora avisa, mas não estima o
          valor pago à parte.
        </li>
      </ul>
    </section>
  );
}
