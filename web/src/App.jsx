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
            Regras de 2026 a 2028, com a base legal
          </p>
          <h1 id="titulo">Calculadora do Simples Nacional</h1>
          <p className="hero-subtitulo">Estimativa educativa do DAS</p>
          <p className="hero-texto">
            Informe as receitas do mês como no <span className="sem-quebra">PGDAS-D</span>, uma por
            atividade, e veja o DAS de cada uma, quanto vai para cada tributo, o que é pago fora do
            DAS, a multa e os juros do atraso e a conta explicada passo a passo. Também calcula o
            DAS do MEI.
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
          descricao="Valores em reais, com ou sem pontos. A conta usa as tabelas da Lei Complementar 123/2006 (2026) e as da LC 214/2025 (2027 e 2028)."
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

// O que a calculadora faz e o que ela não faz. Ela faz a mesma apuração do PGDAS-D para os
// casos mais comuns, mas quem gera a guia é o PGDAS-D (ou o PGMEI), e os casos da lista de
// baixo pedem um contador.
function Aviso() {
  return (
    <div className="aviso">
      <h3>O que ela faz</h3>
      <ul>
        <li>
          Apura o DAS de meses de <strong>2026 a 2028</strong>, com as regras de cada ano (a partir
          de 2027, a RBT12 pula o mês anterior e entram o IBS e a CBS).
        </li>
        <li>
          Separa as receitas por atividade (até 10), com substituição tributária, monofásico, ISS
          retido, exportação, locação de bens móveis, receita com IPI e ISS ao mesmo tempo e isenção
          ou redução de ICMS e ISS dada pelo estado ou pelo município.
        </li>
        <li>
          Aceita os meses anteriores somados ou mês a mês, início de atividade, Fator R, ICMS e ISS
          em valor fixo, sublimite, receita acima de R$&nbsp;4.800.000,00 (até a exclusão) e o
          limite extra das receitas de exportação.
        </li>
        <li>
          Estima o que é pago fora do DAS (ISS, ICMS, ICMS por substituição tributária, diferencial
          de alíquota, IBS, CBS e a CPP do Anexo IV) com as alíquotas que você informar.
        </li>
        <li>
          Calcula a multa e os juros do DAS pago em atraso, com a Selic de cada mês, e o DAS do MEI,
          com o limite do ano.
        </li>
        <li>Gera a memória de cálculo para imprimir ou salvar em PDF.</li>
      </ul>
      <h3>O que ela não faz</h3>
      <ul>
        <li>
          É uma <strong>estimativa educativa</strong>: a guia oficial sai do{" "}
          <span className="sem-quebra">PGDAS-D</span> (ou do PGMEI), e a responsabilidade pelos
          dados continua sendo da empresa e do contador.
        </li>
        <li>
          Não transmite a declaração, não gera a guia e não calcula a multa por atraso na entrega da
          declaração.
        </li>
        <li>
          As estimativas de fora do DAS usam as alíquotas e a MVA que você informar: a regra de cada
          estado e município (MVA ajustada, fundos de combate à pobreza, benefícios) fica com o
          contador.
        </li>
        <li>
          No MEI que passou do limite em mais de 20%, mostra o que acontece, mas a apuração do ano
          como ME é feita na calculadora do Simples, mês a mês.
        </li>
      </ul>
    </div>
  );
}
