import { dataBrasileira, semQuebra } from "./valores.js";

const ROMANOS = { 1: "I", 2: "II", 3: "III", 4: "IV", 5: "V" };

// O resultado com cara de guia: o DAS em destaque, um "picote" e, embaixo, o resumo e a
// divisão entre os tributos. A conta passo a passo fica em ContaPassoAPasso, em largura
// total, para não esticar só esta coluna quando abre.
export default function Resultado({ resultado, refTitulo, desatualizado }) {
  return (
    <section
      className={desatualizado ? "cartao guia desatualizado" : "cartao guia"}
      aria-labelledby="resultado-titulo"
    >
      {/* O espaço entre os dois textos não aparece (são blocos), mas o leitor de tela lê
          "DAS estimado R$ 3.988,80" em vez de juntar as palavras. */}
      <h2 id="resultado-titulo" ref={refTitulo} tabIndex={-1} className="das">
        <span className="das-rotulo">DAS estimado</span>{" "}
        <span className="das-valor">{resultado.das}</span>
      </h2>
      <p className="das-mes">Referente a {resultado.periodo_nome}</p>

      {desatualizado && (
        <p className="nota nota-aviso">
          Você mudou os dados depois deste cálculo. Clique em Calcular para atualizar.
        </p>
      )}
      {resultado.aviso && <p className="nota nota-aviso">{semQuebra(resultado.aviso)}</p>}

      <div className="picote" aria-hidden="true" />

      <dl className="resumo">
        <Item rotulo="Alíquota efetiva" valor={resultado.aliquota_efetiva} />
        <Item rotulo="RBT12" valor={resultado.rbt12} />
        {resultado.fator_r && <Item rotulo="Fator R" valor={resultado.fator_r} />}
        <Item
          rotulo="Faixa"
          valor={`${resultado.faixa}ª, alíquota nominal de ${resultado.aliquota_nominal}`}
        />
        <Item rotulo="Anexo" valor={`${ROMANOS[resultado.anexo]}: ${resultado.anexo_nome}`} largo />
      </dl>

      <Tributos resultado={resultado} />
    </section>
  );
}

// A conta explicada, um passo por linha: título e base legal à esquerda, a conta à direita
// (no celular, um embaixo do outro). Fecha por padrão; aberta, ocupa a largura da página.
export function ContaPassoAPasso({ resultado }) {
  const { tabela, passos } = resultado;

  return (
    <details className="cartao revelar secao-passos">
      <summary>
        <span className="revelar-textos">
          <span className="revelar-titulo">Ver a conta passo a passo</span>
          <span className="revelar-dica">{passos.length} passos, com a base legal de cada um</span>
        </span>
      </summary>
      <div className="revelar-corpo">
        <ol className="linha-do-tempo">
          {passos.map((passo) => (
            <li key={passo.titulo}>
              <div className="passo-cabeca">
                <h3>{passo.titulo}</h3>
                <p className="fonte">{semQuebra(passo.fonte)}</p>
              </div>
              <p className="passo-texto">{semQuebra(passo.texto)}</p>
            </li>
          ))}
        </ol>
        <p className="fonte">
          Tabela na redação da {tabela.redacao}, em vigor desde {dataBrasileira(tabela.vigencia)}.{" "}
          <a href={tabela.fonte}>Texto da LC 123/2006 no Planalto</a>.
        </p>
      </div>
    </details>
  );
}

// Um par rótulo e valor do resumo. largo: ocupa a linha toda (textos longos).
function Item({ rotulo, valor, largo }) {
  return (
    <div className={largo ? "largo" : undefined}>
      <dt>{rotulo}</dt>
      <dd>{valor}</dd>
    </div>
  );
}

// A divisão do DAS: quanto vai para cada tributo. O percentual é sobre a receita do mês.
function Tributos({ resultado }) {
  const { tributos, das_centavos: das } = resultado;
  // Cada tributo é arredondado para o centavo separado, como o DAS: a soma pode diferir
  // do DAS em alguns centavos.
  const soma = tributos.reduce((total, tributo) => total + tributo.valor_centavos, 0);

  return (
    <>
      <table className="tributos">
        <caption>Divisão do DAS entre os tributos</caption>
        <thead>
          <tr>
            <th scope="col">Tributo</th>
            <th scope="col">% da receita</th>
            <th scope="col">Valor</th>
          </tr>
        </thead>
        <tbody>
          {tributos.map((tributo) => (
            <tr key={tributo.nome}>
              <th scope="row">
                {tributo.nome}
                <Barra parte={tributo.valor_centavos} total={das} />
              </th>
              <td>{tributo.percentual}</td>
              <td>{tributo.valor}</td>
            </tr>
          ))}
        </tbody>
        <tfoot>
          <tr>
            <th scope="row">DAS</th>
            <td>{resultado.aliquota_efetiva}</td>
            <td>{resultado.das}</td>
          </tr>
        </tfoot>
      </table>
      {soma !== das && (
        <p className="fonte">
          Cada tributo é arredondado para o centavo separadamente, por isso a soma da tabela pode
          diferir do DAS em alguns centavos.
        </p>
      )}
    </>
  );
}

// Barra com a parte do tributo no DAS. É um SVG (a largura vai num atributo) porque a CSP
// da página não deixa usar style inline. O leitor de tela pula: o valor está na tabela.
function Barra({ parte, total }) {
  const largura = total > 0 ? (parte / total) * 100 : 0;
  return (
    <svg
      className="barra"
      viewBox="0 0 100 4"
      preserveAspectRatio="none"
      aria-hidden="true"
      focusable="false"
    >
      <rect className="barra-trilho" width="100" height="4" />
      <rect className="barra-parte" width={largura.toFixed(2)} height="4" />
    </svg>
  );
}
