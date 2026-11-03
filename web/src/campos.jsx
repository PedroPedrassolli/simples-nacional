import { useId } from "react";
import { formatarReais, NOMES_DOS_MESES } from "./valores.js";

// Peças do formulário. Cada campo liga a dica e a mensagem de erro ao próprio campo
// (aria-describedby), para o leitor de tela ler as duas junto com o rótulo.

// Um grupo de campos (fieldset), com o título na legenda.
export function Etapa({ titulo, children, dica }) {
  return (
    <fieldset className="etapa">
      <legend>{titulo}</legend>
      {dica && <p className="dica etapa-dica">{dica}</p>}
      {children}
    </fieldset>
  );
}

function descricao(id, dica, erro) {
  return [dica && `${id}-dica`, erro && `${id}-erro`].filter(Boolean).join(" ") || undefined;
}

function Ajuda({ id, dica, erro }) {
  return (
    <>
      {dica && (
        <p id={`${id}-dica`} className="dica">
          {dica}
        </p>
      )}
      {erro && (
        <p id={`${id}-erro`} className="erro-campo">
          {erro}
        </p>
      )}
    </>
  );
}

// Valor em reais. Ao sair do campo, "500000" vira "500.000,00".
export function CampoReais({ nome, rotulo, dica, valor, erro, aoMudar, rotuloOculto }) {
  const id = useId();
  return (
    <div className="campo">
      <label htmlFor={id} className={rotuloOculto ? "so-leitor" : undefined}>
        {rotulo}
      </label>
      {dica && (
        <p id={`${id}-dica`} className="dica">
          {dica}
        </p>
      )}
      <div className={erro ? "reais invalido" : "reais"}>
        <span aria-hidden="true">R$</span>
        <input
          id={id}
          name={nome}
          inputMode="decimal"
          autoComplete="off"
          // "R$ 9.999.999,99" tem 15 caracteres: sobra espaço, e um texto enorme colado
          // não chega à conta.
          maxLength={20}
          placeholder="0,00"
          value={valor}
          onChange={(evento) => aoMudar(evento.target.value)}
          onBlur={(evento) => {
            const formatado = formatarReais(evento.target.value);
            if (formatado !== evento.target.value) aoMudar(formatado, { formatacao: true });
          }}
          aria-invalid={erro ? "true" : undefined}
          aria-describedby={descricao(id, dica, erro)}
        />
      </div>
      <Ajuda id={id} erro={erro} />
    </div>
  );
}

// Percentual (alíquota): "3,5" quer dizer 3,5%. sufixo: "" para número sem "%" (o FAP).
export function CampoPercentual({ nome, rotulo, dica, valor, erro, aoMudar, sufixo = "%" }) {
  const id = useId();
  return (
    <div className="campo">
      <label htmlFor={id}>{rotulo}</label>
      {dica && (
        <p id={`${id}-dica`} className="dica">
          {dica}
        </p>
      )}
      <div className={erro ? "reais percentual invalido" : "reais percentual"}>
        <input
          id={id}
          name={nome}
          inputMode="decimal"
          autoComplete="off"
          maxLength={10}
          placeholder="0,00"
          value={valor}
          onChange={(evento) => aoMudar(evento.target.value)}
          aria-invalid={erro ? "true" : undefined}
          aria-describedby={descricao(id, dica, erro)}
        />
        {sufixo && <span aria-hidden="true">{sufixo}</span>}
      </div>
      <Ajuda id={id} erro={erro} />
    </div>
  );
}

// Lista de opções. vazio: o texto da primeira opção, que não pode ser escolhida de volta.
// grupos: [{ rotulo, opcoes }] para separar por ano; senão, opcoes.
export function CampoLista({ nome, rotulo, dica, vazio, opcoes, grupos, valor, erro, aoMudar }) {
  const id = useId();
  const lista = (itens) =>
    itens.map((opcao) => (
      <option key={opcao.valor} value={opcao.valor}>
        {opcao.rotulo}
      </option>
    ));
  return (
    <div className="campo">
      <label htmlFor={id}>{rotulo}</label>
      {dica && (
        <p id={`${id}-dica`} className="dica">
          {dica}
        </p>
      )}
      <select
        id={id}
        name={nome}
        value={valor}
        onChange={(evento) => aoMudar(evento.target.value)}
        aria-invalid={erro ? "true" : undefined}
        aria-describedby={descricao(id, dica, erro)}
      >
        {vazio && (
          <option value="" disabled>
            {vazio}
          </option>
        )}
        {grupos
          ? grupos.map((grupo) => (
              <optgroup key={grupo.rotulo} label={grupo.rotulo}>
                {lista(grupo.opcoes)}
              </optgroup>
            ))
          : lista(opcoes)}
      </select>
      <Ajuda id={id} erro={erro} />
    </div>
  );
}

// O mês de apuração em duas listas lado a lado (mês e ano), para escolher sem rolar uma lista
// de 36 meses. Os dois rótulos ficam só para o leitor de tela ("Mês de apuração", "Ano de
// apuração"); na tela, a legenda do grupo já diz o que é.
export function CampoMesEAno({ mes, ano, anos, dica, erro, aoMudar }) {
  const id = useId();
  const lista = (nome, rotulo, valor, opcoes) => (
    <div className="campo">
      <label htmlFor={`${id}-${nome}`} className="so-leitor">
        {rotulo} de apuração
      </label>
      <select
        id={`${id}-${nome}`}
        name={`${nome}_apuracao`}
        value={valor}
        onChange={(evento) => aoMudar({ [`${nome}_apuracao`]: evento.target.value })}
        aria-invalid={erro && !valor ? "true" : undefined}
        aria-describedby={descricao(id, dica, erro)}
      >
        <option value="" disabled>
          {rotulo}
        </option>
        {opcoes}
      </select>
    </div>
  );
  return (
    <fieldset className="mes-e-ano">
      <legend>Mês de apuração</legend>
      {dica && (
        <p id={`${id}-dica`} className="dica">
          {dica}
        </p>
      )}
      <div className="mes-e-ano-campos">
        {lista(
          "mes",
          "Mês",
          mes,
          NOMES_DOS_MESES.map((nome, indice) => (
            <option key={nome} value={String(indice + 1).padStart(2, "0")}>
              {nome}
            </option>
          )),
        )}
        {lista(
          "ano",
          "Ano",
          ano,
          anos.map((item) => (
            <option key={item} value={String(item)}>
              {item}
            </option>
          )),
        )}
      </div>
      <Ajuda id={id} erro={erro} />
    </fieldset>
  );
}

// Data (o campo de data do navegador entrega "AAAA-MM-DD", o formato da API).
export function CampoData({ nome, rotulo, dica, valor, erro, aoMudar }) {
  const id = useId();
  return (
    <div className="campo">
      <label htmlFor={id}>{rotulo}</label>
      {dica && (
        <p id={`${id}-dica`} className="dica">
          {dica}
        </p>
      )}
      <input
        id={id}
        name={nome}
        type="date"
        className="data"
        value={valor}
        onChange={(evento) => aoMudar(evento.target.value)}
        aria-invalid={erro ? "true" : undefined}
        aria-describedby={descricao(id, dica, erro)}
      />
      <Ajuda id={id} erro={erro} />
    </div>
  );
}

// Caixa de marcar, com a explicação embaixo. children: o que aparece embaixo quando faz
// sentido (o percentual da redução, por exemplo).
export function Caixa({ nome, rotulo, dica, marcada, aoMudar, children }) {
  const id = useId();
  return (
    <div className="caixa">
      <input
        id={id}
        name={nome}
        type="checkbox"
        checked={marcada}
        onChange={(evento) => aoMudar(evento.target.checked)}
        aria-describedby={dica ? `${id}-dica` : undefined}
      />
      <label htmlFor={id}>{rotulo}</label>
      {dica && (
        <p id={`${id}-dica`} className="dica">
          {dica}
        </p>
      )}
      {children && <div className="caixa-extra">{children}</div>}
    </div>
  );
}

// Duas (ou mais) escolhas com cara de chave: botões de rádio, um ao lado do outro. titulo:
// o texto que aparece em cima (e que o leitor de tela lê como nome do grupo).
export function Alternar({ nome, titulo, opcoes, valor, aoMudar }) {
  const id = useId();
  return (
    <div className="campo">
      <p id={`${id}-titulo`} className="rotulo">
        {titulo}
      </p>
      <div className="alternar" role="radiogroup" aria-labelledby={`${id}-titulo`}>
        {opcoes.map(([codigo, texto]) => (
          <label key={codigo} className={valor === codigo ? "escolhido" : undefined}>
            <input
              type="radio"
              name={nome}
              value={codigo}
              checked={valor === codigo}
              onChange={() => aoMudar(codigo)}
            />
            {texto}
          </label>
        ))}
      </div>
    </div>
  );
}

// Parte que abre e fecha (details), no padrão visual da página.
export function Revelar({ titulo, dica, selo, aberto, aoAlternar, className, children }) {
  return (
    <details
      className={["revelar", className].filter(Boolean).join(" ")}
      open={aberto}
      onToggle={(evento) => aoAlternar?.(evento.currentTarget.open)}
    >
      <summary>
        <span className="revelar-textos">
          <span className="revelar-titulo">
            {titulo} {selo && <span className="selo">{selo}</span>}
          </span>
          {dica && <span className="revelar-dica">{dica}</span>}
        </span>
      </summary>
      <div className="revelar-corpo">{children}</div>
    </details>
  );
}
