import { useState } from "react";
import { dicaDoTipo, marcarOpcao, opcao, opcoesDoTipo, REDUCOES, TIPOS } from "./atividades.js";
import { Caixa, CampoLista, CampoPercentual, CampoReais, Revelar } from "./campos.jsx";
import { novaReceita } from "./formulario.js";
import { paraApi, reais } from "./valores.js";

const MAXIMO = 10;

// As receitas do mês, uma por atividade (a segregação do PGDAS-D). Quem tem uma atividade
// só preenche uma linha; "Adicionar outra receita" abre mais uma.
export default function Receitas({ receitas, ano, erros, aoMudar }) {
  const soma = receitas.reduce((total, receita) => total + Number(paraApi(receita.valor) ?? 0), 0);

  function mudarLinha(indice, mudanca) {
    aoMudar(
      receitas.map((receita, posicao) =>
        posicao === indice ? { ...receita, ...mudanca } : receita,
      ),
    );
  }

  function adicionar() {
    const id = Math.max(...receitas.map((receita) => receita.id)) + 1;
    aoMudar([...receitas, novaReceita(id)]);
  }

  return (
    <>
      <ol className="receitas">
        {receitas.map((receita, indice) => (
          <LinhaDaReceita
            key={receita.id}
            receita={receita}
            indice={indice}
            total={receitas.length}
            ano={ano}
            erros={erros}
            aoMudar={(mudanca) => mudarLinha(indice, mudanca)}
            aoRemover={() => aoMudar(receitas.filter((_, posicao) => posicao !== indice))}
          />
        ))}
      </ol>
      <div className="receitas-rodape">
        <button
          type="button"
          className="botao secundario pequeno"
          onClick={adicionar}
          disabled={receitas.length >= MAXIMO}
        >
          + Adicionar outra receita
        </button>
        {receitas.length > 1 && (
          <p className="receitas-total" aria-live="polite">
            Receita do mês: <strong>{reais(Math.round(soma * 100))}</strong>
          </p>
        )}
      </div>
    </>
  );
}

function LinhaDaReceita({ receita, indice, total, ano, erros, aoMudar, aoRemover }) {
  const opcoes = opcoesDoTipo(receita.tipo, ano);
  const marcadas = receita.opcoes.filter((codigo) => opcoes.includes(codigo));
  // A parte das situações abre sozinha quando já tem alguma marcada (o exemplo, por exemplo).
  const [aberto, setAberto] = useState(marcadas.length > 0);
  const numero = total > 1 ? ` ${indice + 1}` : "";

  function marcar(codigo, marcada) {
    aoMudar({ opcoes: marcarOpcao(receita.opcoes, codigo, marcada) });
  }

  return (
    <li className="receita">
      {total > 1 && (
        <div className="receita-cabeca">
          <span className="receita-numero">Receita {indice + 1}</span>
          <button type="button" className="botao-texto" onClick={aoRemover}>
            Remover<span className="so-leitor"> a receita {indice + 1}</span>
          </button>
        </div>
      )}
      <CampoLista
        nome={`receitas.${indice}.tipo`}
        rotulo={`Tipo da receita${numero}`}
        dica={dicaDoTipo(receita.tipo)}
        vazio="Escolha o tipo"
        opcoes={TIPOS}
        valor={receita.tipo}
        erro={erros[`receitas.${indice}.tipo`]}
        aoMudar={(tipo) => aoMudar({ tipo })}
      />
      <CampoReais
        nome={`receitas.${indice}.valor`}
        rotulo={`Valor no mês${numero}`}
        dica={
          indice === 0
            ? "Vendas e serviços do mês, sem vendas canceladas e descontos incondicionais (LC 123/2006, art. 3º, § 1º)."
            : undefined
        }
        valor={receita.valor}
        erro={erros[`receitas.${indice}.valor`]}
        aoMudar={(valor) => aoMudar({ valor })}
      />
      {opcoes.length > 0 && (
        <Revelar
          className="mini"
          titulo={`Situações especiais${numero}`}
          dica="Substituição tributária, monofásico, ISS retido, exportação, isenção ou redução"
          selo={
            marcadas.length > 0
              ? `${marcadas.length} marcada${marcadas.length > 1 ? "s" : ""}`
              : undefined
          }
          aberto={aberto}
          aoAlternar={setAberto}
        >
          {opcoes.map((codigo) => (
            <Caixa
              key={codigo}
              nome={`receitas.${indice}.${codigo}`}
              rotulo={opcao(codigo, ano).rotulo}
              dica={opcao(codigo, ano).dica}
              marcada={receita.opcoes.includes(codigo)}
              aoMudar={(marcada) => marcar(codigo, marcada)}
            >
              {codigo in REDUCOES && receita.opcoes.includes(codigo) && (
                <CampoPercentual
                  nome={`receitas.${indice}.${codigo}.percentual`}
                  rotulo={`Redução do ${REDUCOES[codigo]}${numero}`}
                  valor={receita.reducoes?.[codigo] ?? ""}
                  erro={erros[`receitas.${indice}.${codigo}`]}
                  aoMudar={(valor) =>
                    aoMudar({ reducoes: { ...receita.reducoes, [codigo]: valor } })
                  }
                />
              )}
            </Caixa>
          ))}
        </Revelar>
      )}
    </li>
  );
}
