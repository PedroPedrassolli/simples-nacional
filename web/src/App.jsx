import Calculadora from "./Calculadora.jsx";
import ConsultaCnpj from "./ConsultaCnpj.jsx";
import { IconeCodigo, IconeLua, IconeSeta, IconeSol } from "./icones.jsx";
import { useTema } from "./tema.js";

const REPOSITORIO = "https://github.com/PedroPedrassolli/simples-nacional";
const PORTFOLIO = "https://pedrassolli.vercel.app";

// A página inteira, no mesmo padrão visual do portfólio: cabeçalho fixo com a marca e o
// botão de tema, abertura (hero), seções com título grande e rodapé com o lema.
// No build ela vira HTML pronto (scripts/prerender.mjs), e o React só assume os eventos
// no navegador: o texto aparece antes do JavaScript e nada pula de lugar.
export default function App() {
  return (
    <>
      <a className="pular" href="#conteudo">
        Pular para o conteúdo
      </a>
      <Cabecalho />

      <main id="conteudo" tabIndex={-1}>
        <section className="hero" aria-labelledby="titulo">
          <p className="hero-selo">
            <span className="hero-ponto" aria-hidden="true" />
            Regras de 2026, com a base legal
          </p>
          <h1 id="titulo">Calculadora do Simples Nacional</h1>
          <p className="hero-subtitulo">Estimativa educativa do DAS</p>
          <p className="hero-texto">
            Informe a receita e o anexo da atividade e veja a alíquota efetiva, quanto vai para cada
            tributo e a conta explicada passo a passo.
          </p>
          <div className="hero-acoes">
            <a className="botao primario" href="#calculadora">
              Calcular o DAS <IconeSeta />
            </a>
            <a className="botao secundario" href={REPOSITORIO}>
              <IconeCodigo /> Código no GitHub
            </a>
          </div>
        </section>

        <Secao
          id="calculadora"
          titulo="Calcule o DAS"
          descricao="Valores em reais, com ou sem pontos. A conta é feita pelas tabelas da Lei Complementar 123/2006."
        >
          <Calculadora consulta={<ConsultaCnpj />} />
        </Secao>

        <Secao id="antes-de-usar" titulo="Antes de usar">
          <Aviso />
        </Secao>
      </main>

      <footer className="rodape">
        <p className="rodape-lema">Regra de negócio confusa em código claro.</p>
        <p className="rodape-meta">
          Feito por <a href={PORTFOLIO}>Pedro Pedrassolli</a>. Código aberto no{" "}
          <a href={REPOSITORIO}>GitHub</a>, com a fonte oficial de cada tabela.{" "}
          <a href="#topo">Voltar ao topo</a>
        </p>
      </footer>
    </>
  );
}

// Cabeçalho fixo, como o do portfólio: a marca leva ao portfólio, o menu leva às partes
// desta página (só no computador) e os botões ficam à direita.
function Cabecalho() {
  return (
    <header className="cabecalho" id="topo">
      <div className="cabecalho-dentro">
        <a className="marca" href={PORTFOLIO}>
          <span className="marca-sigla" aria-hidden="true">
            pp
          </span>
          <span className="marca-nome">Pedro Pedrassolli</span>
        </a>

        <nav className="menu" aria-label="Nesta página">
          <ul>
            <li>
              <a href="#calculadora">Calcular</a>
            </li>
            <li>
              <a href="#cnpj">Consultar CNPJ</a>
            </li>
            <li>
              <a href="#antes-de-usar">Antes de usar</a>
            </li>
          </ul>
        </nav>

        <div className="cabecalho-acoes">
          <a
            className="botao-redondo"
            href={REPOSITORIO}
            aria-label="Código no GitHub"
            title="Código no GitHub"
          >
            <IconeCodigo tamanho={18} />
          </a>
          <BotaoTema />
        </div>
      </div>
    </header>
  );
}

function BotaoTema() {
  const { tema, alternar } = useTema();
  const escuro = tema === "dark";
  const rotulo = escuro ? "Usar tema claro" : "Usar tema escuro";

  return (
    <button
      type="button"
      className="botao-redondo"
      onClick={alternar}
      aria-label={rotulo}
      title={rotulo}
    >
      {escuro ? <IconeSol tamanho={18} /> : <IconeLua tamanho={18} />}
    </button>
  );
}

// Seção com título grande e descrição, como as do portfólio (Section.jsx).
function Secao({ id, titulo, descricao, children }) {
  return (
    <section id={id} className="secao" aria-labelledby={`${id}-titulo`}>
      <header className="secao-cabeca">
        <h2 id={`${id}-titulo`} className="secao-titulo">
          {titulo}
        </h2>
        {descricao && <p className="secao-descricao">{descricao}</p>}
      </header>
      {children}
    </section>
  );
}

function Aviso() {
  return (
    <div className="aviso">
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
          Não cobre receita acima de R$&nbsp;4.800.000,00 no ano (a empresa sai do Simples) nem tira
          a parcela do ISS da locação de bens móveis.
        </li>
        <li>
          Quando o ICMS ou o ISS sai do DAS pelo sublimite, a calculadora avisa, mas não estima o
          valor pago à parte.
        </li>
      </ul>
    </div>
  );
}
