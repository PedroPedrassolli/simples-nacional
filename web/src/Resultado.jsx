import { dataBrasileira, semQuebra } from "./valores.js";

const ROMANOS = { 1: "I", 2: "II", 3: "III", 4: "IV", 5: "V" };

// O resultado com cara de guia: o DAS em destaque, um "picote" e, embaixo, o resumo, as
// receitas, a divisão entre os tributos e o que fica fora do DAS. A conta passo a passo fica
// em ContaPassoAPasso, em largura total, para não esticar só esta coluna quando abre.
export default function Resultado({ resultado, refTitulo, desatualizado }) {
  const varias = resultado.atividades.length > 1;
  const primeira = resultado.atividades[0];

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
      {resultado.avisos.map((aviso) => (
        <p key={aviso} className="nota nota-aviso">
          {semQuebra(aviso)}
        </p>
      ))}

      <div className="picote" aria-hidden="true" />

      <dl className="resumo">
        <Item
          rotulo={varias ? "Alíquota média" : "Alíquota efetiva"}
          valor={resultado.aliquota_efetiva}
        />
        <Item rotulo="RBT12" valor={resultado.rbt12} />
        {resultado.fator_r && <Item rotulo="Fator R" valor={resultado.fator_r} />}
        {!varias && (
          <>
            <Item
              rotulo="Faixa"
              valor={`${resultado.faixa}ª, alíquota nominal de ${resultado.aliquota_nominal}`}
            />
            <Item
              rotulo="Anexo"
              valor={`${ROMANOS[primeira.anexo]} – ${primeira.anexo_nome}`}
              largo
            />
          </>
        )}
      </dl>

      {varias && <Receitas atividades={resultado.atividades} />}
      <Tributos
        tributos={resultado.tributos}
        rodape={["DAS", resultado.aliquota_efetiva, resultado.das]}
      />
      {resultado.fora_do_das.length > 0 && <ForaDoDas resultado={resultado} />}
      {resultado.atraso && <Atraso atraso={resultado.atraso} das={resultado.das} />}

      <div className="acoes-resultado">
        <button type="button" className="botao secundario pequeno" onClick={() => window.print()}>
          Imprimir ou salvar a memória de cálculo
        </button>
      </div>
    </section>
  );
}

// Uma linha por receita: o nome e o DAS dela; embaixo, a receita, o anexo, a faixa e o
// percentual. Lista, e não tabela, para caber no celular. As situações especiais de cada uma
// ficam na conta passo a passo ("O que esta receita não paga no DAS").
function Receitas({ atividades }) {
  return (
    <div className="receitas-resultado">
      <h3>DAS de cada receita</h3>
      <ul>
        {atividades.map((atividade) => (
          <li key={atividade.numero}>
            <span className="receita-nome">
              {atividade.numero}. {atividade.nome}
            </span>
            <strong className="receita-valor">{atividade.valor}</strong>
            <span className="detalhe">
              {semQuebra(
                `${atividade.receita} de receita · Anexo ${ROMANOS[atividade.anexo]}, ${atividade.faixa}ª faixa · ${atividade.percentual}`,
              )}
            </span>
          </li>
        ))}
      </ul>
    </div>
  );
}

// O DAS pago depois do vencimento: multa, juros e o total a pagar (também no MEI).
export function Atraso({ atraso, das }) {
  return (
    <div className="atraso">
      <h3>Pago em {atraso.pagamento}</h3>
      {atraso.dias === 0 ? (
        <p className="detalhe">
          Dentro do prazo (vencimento em {atraso.vencimento}): sem multa nem juros.
        </p>
      ) : (
        <dl className="atraso-contas">
          <div>
            <dt>DAS</dt>
            <dd>{das}</dd>
          </div>
          <div>
            <dt>
              Multa ({atraso.multa_percentual}, {atraso.dias} {atraso.dias === 1 ? "dia" : "dias"})
            </dt>
            <dd>{atraso.multa}</dd>
          </div>
          <div>
            <dt>Juros ({atraso.juros_percentual})</dt>
            <dd>{atraso.juros}</dd>
          </div>
          <div className="atraso-total">
            <dt>Total a pagar</dt>
            <dd>{atraso.total}</dd>
          </div>
        </dl>
      )}
    </div>
  );
}

// A divisão do DAS: quanto vai para cada tributo. O percentual é sobre a receita do mês.
// rodape: [rótulo, percentual, valor] da última linha.
export function Tributos({ tributos, rodape, legenda = "Divisão do DAS entre os tributos" }) {
  const total = tributos.reduce((soma, tributo) => soma + tributo.valor_centavos, 0);
  const [rotulo, percentual, valor] = rodape;
  const valorDoRodape = Number(valor.replace(/\D/g, ""));

  return (
    <>
      <table className="tabela tributos">
        <caption>{legenda}</caption>
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
                <Barra parte={tributo.valor_centavos} total={total} />
              </th>
              <td>{tributo.percentual}</td>
              <td>{tributo.valor}</td>
            </tr>
          ))}
        </tbody>
        <tfoot>
          <tr>
            <th scope="row">{rotulo}</th>
            <td>{percentual}</td>
            <td>{valor}</td>
          </tr>
        </tfoot>
      </table>
      {/* Cada tributo é arredondado para o centavo separadamente. */}
      {total !== valorDoRodape && (
        <p className="fonte">
          Cada tributo é arredondado para o centavo separadamente, por isso a soma da tabela pode
          diferir do total em alguns centavos.
        </p>
      )}
    </>
  );
}

// O que é pago à parte, com a estimativa (ou o dado que falta) e o total do mês.
function ForaDoDas({ resultado }) {
  return (
    <div className="fora">
      <h3>Fora do DAS</h3>
      <ul className="fora-lista">
        {resultado.fora_do_das.map((estimativa) => (
          <li key={estimativa.tributo}>
            <span className="fora-nome">{estimativa.tributo}</span>
            <span className="fora-valor">{estimativa.valor ?? "a estimar"}</span>
            <span className="fora-texto">{semQuebra(estimativa.falta ?? estimativa.texto)}</span>
          </li>
        ))}
      </ul>
      <p className="fora-total">
        <span>Total estimado do mês (DAS + fora do DAS)</span>
        <strong>{resultado.total_estimado}</strong>
      </p>
    </div>
  );
}

// A conta explicada, agrupada (receitas anteriores, cada receita do mês, sublimite, fora do
// DAS, total): título e base legal à esquerda, a conta à direita. Fecha por padrão.
export function ContaPassoAPasso({ resultado }) {
  const { tabela, passos } = resultado;
  const grupos = agrupar(passos);

  return (
    <details className="cartao revelar secao-passos">
      <summary>
        <span className="revelar-textos">
          <span className="revelar-titulo">Ver a conta passo a passo</span>
          <span className="revelar-dica">{passos.length} passos, com a base legal de cada um</span>
        </span>
      </summary>
      <div className="revelar-corpo">
        {grupos.map(([grupo, itens]) => (
          <section key={grupo} className="grupo-de-passos" aria-label={grupo}>
            <h3>{grupo}</h3>
            <ol className="linha-do-tempo">
              {itens.map((passo) => (
                <li key={`${grupo}-${passo.titulo}`}>
                  <div className="passo-cabeca">
                    <h4>{passo.titulo}</h4>
                    <p className="fonte">{semQuebra(passo.fonte)}</p>
                  </div>
                  <p className="passo-texto">{semQuebra(passo.texto)}</p>
                </li>
              ))}
            </ol>
          </section>
        ))}
        {/* O MEI não tem tabela: os valores fixos estão nos passos. */}
        {tabela && (
          <p className="fonte">
            {resultado.atividades.length === 1
              ? `Tabela na redação da ${tabela.redacao}, em vigor desde ${dataBrasileira(tabela.vigencia)}. `
              : `Tabelas em vigor desde ${dataBrasileira(tabela.vigencia)}. `}
            <a href={tabela.fonte}>Texto da lei no Planalto</a>.
          </p>
        )}
      </div>
    </details>
  );
}

// [[grupo, [passos]], ...] na ordem em que vieram.
export function agrupar(passos) {
  const grupos = new Map();
  for (const passo of passos) {
    if (!grupos.has(passo.grupo)) grupos.set(passo.grupo, []);
    grupos.get(passo.grupo).push(passo);
  }
  return [...grupos];
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
