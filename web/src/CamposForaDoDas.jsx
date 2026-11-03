import { CampoLista, CampoPercentual, CampoReais, Revelar } from "./campos.jsx";
import { ROTULOS_DE_FORA } from "./formulario.js";
import { regrasDoAno } from "./periodos.js";

const RATS = [
  { valor: "", rotulo: "Não sei / não informar" },
  { valor: "1", rotulo: "1% (risco leve)" },
  { valor: "2", rotulo: "2% (risco médio)" },
  { valor: "3", rotulo: "3% (risco grave)" },
];

// Dados opcionais para estimar o que é pago fora do DAS. A calculadora só usa o que fizer
// sentido para o resultado (e diz no resultado quando falta algum).
export default function CamposForaDoDas({ valores, erros, resumo, aoMudar, aberto, aoAlternar }) {
  const { novas } = regrasDoAno(valores.periodo);
  const fora = valores.fora;
  const props = (nome) => ({
    nome: `fora.${nome}`,
    rotulo: ROTULOS_DE_FORA[nome],
    valor: fora[nome],
    erro: erros[`fora.${nome}`],
    aoMudar: (valor, como) => aoMudar({ fora: { ...fora, [nome]: valor } }, como),
  });

  return (
    <Revelar
      className="opcional"
      titulo="Tributos pagos fora do DAS"
      selo="opcional"
      dica="Para estimar o ISS, o ICMS, o IBS, a CBS e a CPP pagos à parte"
      aberto={aberto}
      aoAlternar={aoAlternar}
    >
      <p className="dica">
        Só entram quando o resultado diz que o tributo ficou fora do DAS (sublimite, Anexo IV ou IBS
        e CBS no regime regular). A guia de cada um sai do município, do estado ou da Receita
        Federal; aqui é uma estimativa.
      </p>
      <h3 className="subtitulo">ISS e ICMS</h3>
      <div className="grade">
        <CampoPercentual
          {...props("aliquota_iss")}
          dica="De 2% a 5% (LC 116/2003, arts. 8º e 8º-A)."
        />
        <CampoPercentual {...props("aliquota_icms")} />
        <CampoReais {...props("creditos_icms")} />
      </div>
      {novas && (
        <>
          <h3 className="subtitulo">IBS e CBS (2027 em diante)</h3>
          <div className="grade">
            <CampoPercentual {...props("aliquota_ibs")} />
            <CampoReais {...props("creditos_ibs")} />
            {valores.ibs_cbs_fora && (
              <>
                <CampoPercentual {...props("aliquota_cbs")} />
                <CampoReais {...props("creditos_cbs")} />
              </>
            )}
          </div>
        </>
      )}
      {resumo.anexoIV && (
        <>
          <h3 className="subtitulo">CPP do Anexo IV</h3>
          <div className="grade">
            <CampoReais
              {...props("folha_empregados")}
              dica="Base da contribuição de 20% e do RAT (Lei 8.212/1991, art. 22, I e II)."
            />
            <CampoReais {...props("pro_labore")} dica="20% (Lei 8.212/1991, art. 22, III)." />
            <CampoLista {...props("rat")} opcoes={RATS} />
            <CampoPercentual
              {...props("fap")}
              sufixo=""
              dica="De 0,5 a 2,0 (Lei 10.666/2003, art. 10). Em branco, vale 1."
            />
          </div>
        </>
      )}
    </Revelar>
  );
}
