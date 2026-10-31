import { useEffect, useId, useRef, useState } from "react";
import { calcular } from "./api.js";
import { ANEXOS, dicaDoAnexo } from "./anexos.js";
import {
  conferir,
  formatarReais,
  MESES_DE_APURACAO,
  mesesDeInicio,
  nomeDoMes,
  podePassarDoSublimite,
  textosDosCampos,
} from "./valores.js";
import Resultado, { ContaPassoAPasso } from "./Resultado.jsx";

const PERIODOS = MESES_DE_APURACAO.map((mes) => ({ valor: mes, rotulo: nomeDoMes(mes) }));

const VAZIO = {
  periodo: "",
  inicio: "",
  rbt12: "",
  receita_mes: "",
  receita_ano: "",
  receita_ano_anterior: "",
  anexo: "",
  folha12: "",
};

// Números fictícios (uma prestadora de serviços do Anexo III), para ver a calculadora
// funcionando antes de juntar os números da empresa.
const EXEMPLO = {
  ...VAZIO,
  periodo: "2026-03",
  rbt12: "500.000,00",
  receita_mes: "40.000,00",
  anexo: "3",
};

const SEM_RESULTADO = { carregando: false, resultado: null, erro: null };

// O formulário e, ao lado (abaixo, no celular), o resultado. Embaixo do formulário vai a
// consulta de CNPJ (consulta), e a conta passo a passo ocupa a largura toda. A posição de
// cada parte no computador fica no estilo.css (.layout).
export default function Calculadora({ consulta }) {
  const [valores, setValores] = useState(VAZIO);
  const [erros, setErros] = useState({});
  const [estado, setEstado] = useState(SEM_RESULTADO);
  // O resultado na tela foi calculado com outros valores: a pessoa mudou um campo depois.
  const [desatualizado, setDesatualizado] = useState(false);
  const [sublimiteAberto, setSublimiteAberto] = useState(false);
  // Aumenta a cada tentativa com erro, para o efeito abaixo levar o foco ao primeiro campo.
  const [tentativasComErro, setTentativasComErro] = useState(0);
  // Número do último pedido à API: uma resposta atrasada de um pedido antigo é ignorada.
  const pedido = useRef(0);
  const formulario = useRef(null);
  const tituloResultado = useRef(null);
  const textos = textosDosCampos(valores.periodo, valores.inicio);

  // Leva o foco para o resultado: quem usa leitor de tela ouve o DAS logo depois de
  // calcular, e no celular a página rola até ele.
  useEffect(() => {
    if (estado.resultado) tituloResultado.current?.focus();
  }, [estado.resultado]);

  // Com erro, o foco vai para o primeiro campo com problema (o leitor de tela lê a mensagem).
  useEffect(() => {
    if (tentativasComErro > 0) formulario.current?.querySelector("[aria-invalid=true]")?.focus();
  }, [tentativasComErro]);

  function mudar(evento) {
    const { name, value } = evento.target;
    const novos = { ...valores, [name]: value };
    // Trocou o mês de apuração e o início escolhido ficou fora da lista: volta para "12 meses ou mais".
    if (name === "periodo" && !mesesDeInicio(value).includes(novos.inicio)) novos.inicio = "";
    // Os valores acabaram de passar do sublimite: abre os campos opcionais dele.
    if (!podePassarDoSublimite(valores) && podePassarDoSublimite(novos)) setSublimiteAberto(true);
    if (estado.resultado) setDesatualizado(true);
    setValores(novos);
  }

  // Ao sair de um campo de valor, mostra "500.000,00" em vez de "500000". O valor é o
  // mesmo, então o resultado na tela não fica desatualizado.
  function formatar(evento) {
    const { name, value } = evento.target;
    const formatado = formatarReais(value);
    if (formatado !== value) setValores({ ...valores, [name]: formatado });
  }

  async function enviar(evento) {
    evento.preventDefault();
    const conferido = conferir(valores);
    setErros(conferido.erros);
    if (
      conferido.erros.receita_ano ||
      conferido.erros.receita_ano_anterior ||
      podePassarDoSublimite(valores)
    ) {
      setSublimiteAberto(true);
    }
    if (Object.keys(conferido.erros).length > 0) {
      setTentativasComErro((total) => total + 1);
      return;
    }

    const estePedido = ++pedido.current;
    setEstado({ carregando: true, resultado: null, erro: null });
    const { resultado, erro } = await calcular(conferido.parametros);
    // Enquanto esperava, a pessoa limpou o formulário ou pediu outro cálculo.
    if (estePedido !== pedido.current) return;
    setEstado({ carregando: false, resultado: resultado ?? null, erro: erro ?? null });
    setDesatualizado(false);
  }

  function recomecar(novosValores) {
    pedido.current++;
    setValores(novosValores);
    setErros({});
    setEstado(SEM_RESULTADO);
    setDesatualizado(false);
    setSublimiteAberto(false);
  }

  const inicios = [
    { valor: "", rotulo: "Há 12 meses ou mais" },
    ...mesesDeInicio(valores.periodo).map((mes) => ({ valor: mes, rotulo: nomeDoMes(mes) })),
  ];
  const campo = { valores, erros, aoMudar: mudar, aoSair: formatar };

  return (
    <div className="layout">
      <form ref={formulario} className="formulario cartao" onSubmit={enviar} noValidate>
        <Etapa titulo="Mês e empresa">
          <CampoLista
            nome="periodo"
            rotulo="Mês de apuração"
            dica="O mês do DAS que você quer calcular. Por enquanto, só meses de 2026."
            vazio="Escolha o mês"
            opcoes={PERIODOS}
            {...campo}
          />
          <CampoLista
            nome="inicio"
            rotulo="Início das atividades"
            dica="Se a empresa começou há menos de 12 meses, escolha o mês em que ela começou. A lista aparece depois do mês de apuração."
            opcoes={inicios}
            {...campo}
          />
        </Etapa>

        <Etapa titulo="Receitas">
          {textos.receita ? (
            <CampoReais nome="rbt12" rotulo={textos.receita} dica={textos.dicaReceita} {...campo} />
          ) : (
            <p className="nota">
              No 1º mês de atividade, a receita dos 12 meses (RBT12) é a receita do mês × 12.
            </p>
          )}
          <CampoReais
            nome="receita_mes"
            rotulo="Receita bruta do mês"
            dica="Vendas de bens e serviços do mês, sem as vendas canceladas e os descontos incondicionais (LC 123/2006, art. 3º, § 1º)."
            {...campo}
          />
          {(textos.receitaAno || textos.receitaAnoAnterior) && (
            <details
              className="revelar opcional"
              open={sublimiteAberto}
              onToggle={(evento) => setSublimiteAberto(evento.currentTarget.open)}
            >
              <summary>
                <span className="revelar-textos">
                  <span className="revelar-titulo">
                    Sublimite do ICMS e do ISS <span className="selo">opcional</span>
                  </span>
                  <span className="revelar-dica">
                    Para quem pode passar de R$&nbsp;3.600.000,00 de receita no ano
                  </span>
                </span>
              </summary>
              <div className="revelar-corpo">
                <p className="dica">
                  {podePassarDoSublimite(valores)
                    ? "Com esses valores, a receita do ano pode passar de R$\u00a03.600.000,00. Informe a receita do ano para a conta do ICMS e do ISS."
                    : "Acima de R$\u00a03.600.000,00 no ano, o ICMS e o ISS mudam de regra. Em branco, a conta considera que a empresa não passou desse valor; se faltar algum número, ela avisa."}
                </p>
                {textos.receitaAno && (
                  <CampoReais nome="receita_ano" rotulo={textos.receitaAno} {...campo} />
                )}
                {textos.receitaAnoAnterior && (
                  <CampoReais
                    nome="receita_ano_anterior"
                    rotulo={textos.receitaAnoAnterior}
                    {...campo}
                  />
                )}
              </div>
            </details>
          )}
        </Etapa>

        <Etapa titulo="Atividade">
          <CampoLista
            nome="anexo"
            rotulo="Anexo da atividade"
            dica={dicaDoAnexo(valores.anexo)}
            vazio="Escolha o anexo"
            opcoes={ANEXOS}
            {...campo}
          />
          {valores.anexo === "fator_r" && (
            <CampoReais
              nome="folha12"
              rotulo={textos.folha}
              dica="Com encargos: salários, pró-labore, contribuição patronal ao INSS e FGTS. Aluguéis e distribuição de lucros não entram (LC 123/2006, art. 18, §§ 24 e 26)."
              {...campo}
            />
          )}
        </Etapa>

        <div className="acoes">
          <button type="submit" className="botao primario" disabled={estado.carregando}>
            {estado.carregando ? "Calculando…" : "Calcular"}
          </button>
          <button type="button" className="botao secundario" onClick={() => recomecar(EXEMPLO)}>
            Usar um exemplo
          </button>
          <button type="button" className="botao discreto" onClick={() => recomecar(VAZIO)}>
            Limpar
          </button>
        </div>

        {estado.erro && (
          <p className="erro" role="alert">
            {estado.erro}
          </p>
        )}
      </form>

      <div className="lateral">
        {estado.resultado ? (
          <Resultado
            resultado={estado.resultado}
            refTitulo={tituloResultado}
            desatualizado={desatualizado}
          />
        ) : (
          <ComoFunciona carregando={estado.carregando} />
        )}
      </div>

      {estado.resultado && <ContaPassoAPasso resultado={estado.resultado} />}

      <div className="consulta">{consulta}</div>
    </div>
  );
}

// Um grupo de campos do formulário (fieldset), com o título na legenda.
function Etapa({ titulo, children }) {
  return (
    <fieldset className="etapa">
      <legend>{titulo}</legend>
      {children}
    </fieldset>
  );
}

// A guia "em branco" antes do primeiro cálculo (e enquanto a API responde): diz onde o
// resultado vai aparecer e resume a conta.
function ComoFunciona({ carregando }) {
  return (
    <section className="cartao como" aria-labelledby="como-titulo" aria-busy={carregando}>
      <p className={carregando ? "como-estado carregando" : "como-estado"}>
        {carregando && <span className="girando" aria-hidden="true" />}
        {carregando
          ? "Calculando o DAS…"
          : "Preencha os dados e clique em Calcular: o DAS aparece aqui."}
      </p>
      <h2 id="como-titulo">Como a conta é feita</h2>
      <ol>
        <li>
          <strong>Faixa.</strong> A receita dos 12 meses anteriores (RBT12) diz em qual das 6 faixas
          do anexo a empresa está.
        </li>
        <li>
          <strong>Alíquota efetiva.</strong> (RBT12 × alíquota nominal − parcela a deduzir) ÷ RBT12.
        </li>
        <li>
          <strong>DAS.</strong> Receita do mês × alíquota efetiva.
        </li>
        <li>
          <strong>Divisão.</strong> O DAS é repartido entre os tributos, como IRPJ, CSLL, Cofins,
          PIS/Pasep, CPP e ICMS ou ISS, pelos percentuais de cada anexo.
        </li>
      </ol>
      <p className="fonte">LC 123/2006, art. 18, §§ 1º, 1º-A e 3º, e Anexos I a V.</p>
    </section>
  );
}

// Campo de valor em reais, com dica e mensagem de erro ligadas ao campo (aria-describedby),
// para o leitor de tela ler as duas junto com o rótulo.
function CampoReais({ nome, rotulo, dica, valores, erros, aoMudar, aoSair }) {
  const id = useId();
  const erro = erros[nome];
  const descricao = [dica && `${id}-dica`, erro && `${id}-erro`].filter(Boolean).join(" ");

  return (
    <div className="campo">
      <label htmlFor={id}>{rotulo}</label>
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
          value={valores[nome]}
          onChange={aoMudar}
          onBlur={aoSair}
          aria-invalid={erro ? "true" : undefined}
          aria-describedby={descricao || undefined}
        />
      </div>
      {erro && (
        <p id={`${id}-erro`} className="erro-campo">
          {erro}
        </p>
      )}
    </div>
  );
}

// Lista de opções (mês, início, anexo). vazio: o texto da primeira opção, que não pode
// ser escolhida de volta; sem ele, a primeira opção da lista vale como padrão.
function CampoLista({ nome, rotulo, dica, vazio, opcoes, valores, erros, aoMudar }) {
  const id = useId();
  const erro = erros[nome];
  const descricao = [`${id}-dica`, erro && `${id}-erro`].filter(Boolean).join(" ");

  return (
    <div className="campo">
      <label htmlFor={id}>{rotulo}</label>
      <p id={`${id}-dica`} className="dica">
        {dica}
      </p>
      <select
        id={id}
        name={nome}
        value={valores[nome]}
        onChange={aoMudar}
        aria-invalid={erro ? "true" : undefined}
        aria-describedby={descricao}
      >
        {vazio && (
          <option value="" disabled>
            {vazio}
          </option>
        )}
        {opcoes.map((opcao) => (
          <option key={opcao.valor} value={opcao.valor}>
            {opcao.rotulo}
          </option>
        ))}
      </select>
      {erro && (
        <p id={`${id}-erro`} className="erro-campo">
          {erro}
        </p>
      )}
    </div>
  );
}
