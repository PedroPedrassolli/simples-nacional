import { CampoLista, CampoPercentual, CampoReais, Revelar } from "./campos.jsx";
import { regrasDoAno } from "./periodos.js";

const RATS = [
  { valor: "", rotulo: "Não sei" },
  { valor: "1", rotulo: "1% (leve)" },
  { valor: "2", rotulo: "2% (médio)" },
  { valor: "3", rotulo: "3% (grave)" },
];

// Os nomes que aparecem na tela. Cada grupo é um fieldset com o nome do tributo na legenda,
// então o campo pode ter um nome curto (o leitor de tela lê a legenda junto). Os nomes
// completos, para a memória de cálculo, ficam em ROTULOS_DE_FORA (formulario.js).
const ROTULOS = {
  aliquota_iss: "Alíquota do ISS",
  aliquota_icms: "Alíquota do ICMS",
  creditos_icms: "Créditos de ICMS",
  st_valor: "Valor da venda",
  st_ipi: "IPI e encargos",
  st_mva: "MVA",
  st_aliquota_interna: "Alíquota no destino",
  st_aliquota_propria: "Alíquota própria",
  difal_valor: "Compras do mês",
  difal_aliquota_interna: "Alíquota interna",
  difal_aliquota_interestadual: "Alíquota interestadual",
  aliquota_ibs: "Alíquota do IBS",
  creditos_ibs: "Créditos de IBS",
  aliquota_cbs: "Alíquota da CBS",
  creditos_cbs: "Créditos de CBS",
  folha_empregados: "Salários dos empregados",
  pro_labore: "Pró-labore e autônomos",
  rat: "RAT",
  fap: "FAP",
};

// Dados opcionais para estimar o que é pago fora do DAS. A calculadora só usa o que fizer
// sentido para o resultado (e diz no resultado quando falta algum).
export default function CamposForaDoDas({ valores, erros, resumo, aoMudar, aberto, aoAlternar }) {
  const { novas } = regrasDoAno(valores.periodo);
  const fora = valores.fora;
  const props = (nome) => ({
    nome: `fora.${nome}`,
    rotulo: ROTULOS[nome],
    valor: fora[nome],
    erro: erros[`fora.${nome}`],
    aoMudar: (valor, como) => aoMudar({ fora: { ...fora, [nome]: valor } }, como),
  });

  return (
    <Revelar
      className="opcional"
      titulo="Tributos pagos fora do DAS"
      selo="opcional"
      dica="ISS, ICMS, ICMS-ST, DIFAL, IBS, CBS e a CPP do Anexo IV"
      aberto={aberto}
      aoAlternar={aoAlternar}
    >
      <p className="dica">
        Preencha só o que a empresa tem. A guia de cada um sai do município, do estado ou da Receita
        Federal; aqui é uma estimativa com as alíquotas que você informar.
      </p>
      <Grupo
        titulo="ISS e ICMS"
        dica="Só entram quando o resultado diz que o ISS ou o ICMS ficou fora do DAS (sublimite). O ISS vai de 2% a 5% (LC 116/2003, arts. 8º e 8º-A)."
      >
        <CampoPercentual {...props("aliquota_iss")} />
        <CampoPercentual {...props("aliquota_icms")} />
        <CampoReais {...props("creditos_icms")} />
      </Grupo>
      <Grupo
        titulo="ICMS por substituição tributária"
        dica="Quando a empresa vende como substituta tributária, o ICMS-ST vai numa guia do estado (LC 123/2006, art. 13, § 1º, XIII, a). Use a MVA original; na venda para outro estado, a alíquota própria é a interestadual (Convênio ICMS 142/2018)."
      >
        <CampoReais {...props("st_valor")} />
        <CampoReais {...props("st_ipi")} />
        <CampoPercentual {...props("st_mva")} />
        <CampoPercentual {...props("st_aliquota_interna")} />
        <CampoPercentual {...props("st_aliquota_propria")} />
      </Grupo>
      <Grupo
        titulo="Diferencial de alíquota (DIFAL)"
        dica="Compras de outros estados para uso, consumo ou o ativo imobilizado (LC 123/2006, art. 13, § 1º, XIII, h)."
      >
        <CampoReais {...props("difal_valor")} />
        <CampoPercentual {...props("difal_aliquota_interna")} />
        <CampoPercentual {...props("difal_aliquota_interestadual")} />
      </Grupo>
      {novas && (
        <Grupo
          titulo="IBS e CBS (2027 em diante)"
          dica="O IBS entra quando passa do sublimite; a CBS, com a opção pelo regime regular."
        >
          <CampoPercentual {...props("aliquota_ibs")} />
          <CampoReais {...props("creditos_ibs")} />
          {valores.ibs_cbs_fora && (
            <>
              <CampoPercentual {...props("aliquota_cbs")} />
              <CampoReais {...props("creditos_cbs")} />
            </>
          )}
        </Grupo>
      )}
      {resumo.anexoIV && (
        <Grupo
          titulo="CPP do Anexo IV"
          dica="20% sobre os salários e o pró-labore, mais o RAT ajustado pelo FAP sobre os salários (Lei 8.212/1991, art. 22, I a III; Lei 10.666/2003, art. 10). FAP em branco vale 1."
        >
          <CampoReais {...props("folha_empregados")} />
          <CampoReais {...props("pro_labore")} />
          <CampoLista {...props("rat")} opcoes={RATS} />
          <CampoPercentual {...props("fap")} sufixo="" />
        </Grupo>
      )}
    </Revelar>
  );
}

// Um tributo: legenda, explicação e os campos lado a lado quando cabem.
function Grupo({ titulo, dica, children }) {
  return (
    <fieldset className="grupo-fora">
      <legend className="subtitulo">{titulo}</legend>
      <p className="dica">{dica}</p>
      <div className="grade">{children}</div>
    </fieldset>
  );
}
