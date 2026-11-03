# Calculadora do Simples Nacional

Estimativa educativa da alíquota efetiva e do DAS do Simples Nacional, com a conta
explicada passo a passo. Regra de negócio confusa em código claro.

**No ar:** [simples-nacional-br.vercel.app](https://simples-nacional-br.vercel.app)

## O que a calculadora faz

Faz a mesma apuração do PGDAS-D para os casos mais comuns, mês a mês, de **janeiro de 2026 a
dezembro de 2028**, e mostra:

- o **DAS estimado**, com a **alíquota efetiva** de cada receita:
  `(RBT12 × alíquota nominal − parcela a deduzir) ÷ RBT12` (LC 123/2006, art. 18, § 1º-A);
- a **divisão do DAS entre os tributos** (IRPJ, CSLL, Cofins, PIS/Pasep, CPP, IPI, ICMS, ISS e,
  a partir de 2027, CBS e IBS), com o ISS limitado a 5% e, na 6ª faixa, o ICMS/ISS/IBS da 5ª;
- o que é pago **fora do DAS**, estimado com as alíquotas que a pessoa informar, e o **total
  do mês** (DAS + fora do DAS);
- a conta **passo a passo**, com a base legal de cada passo, e a **memória de cálculo** para
  imprimir ou salvar em PDF.

**Receitas separadas por atividade (segregação):** até 10 receitas no mês, cada uma no seu
anexo: revenda (Anexo I), indústria (Anexo II em 2026; Anexo I a partir de 2027, menos o
produto com IPI mantido), serviços dos Anexos III, IV e V, serviços pelo Fator R, locação de
bens móveis (Anexo III sem o ISS) e transporte intermunicipal ou comunicação (Anexo III sem o
ISS e com o ICMS do Anexo I). Em cada receita dá para marcar ICMS por substituição tributária,
PIS/Cofins monofásicos (IBS e CBS a partir de 2027), ISS retido e exportação (com RBT12 própria,
Res. CGSN 140/2018, art. 23). Fonte de cada tipo em `lib/simples_nacional/atividades.rb`.

**Meses anteriores:** a soma (RBT12, folha do Fator R) ou o **mês a mês**, como no PGDAS-D.
A partir de 2027 a RBT12 é dos 12 meses antes do mês anterior, e o mês anterior entra à parte,
só na receita do ano (Res. CGSN 140/2018, art. 21, II, a, na redação da Res. CGSN 190/2026).

**Início de atividade:** em 2026, no 1º mês a RBT12 é a receita do mês × 12; depois, a média
dos meses anteriores × 12 (LC 123/2006, art. 18, § 2º; Res. CGSN 140/2018, art. 22). A partir
de 2027, o 1º e o 2º mês usam a 1ª faixa, e o Fator R é 28% (arts. 22 e 26, redação da Res.
190/2026).

**Sublimite e limite:** R$ 3.600.000,00 em todos os estados (Portarias CGSN nº 49/2024 e
nº 54/2025; a partir de 2027, art. 9º da Res. 140 na redação da Res. 190/2026). Com a receita
do ano e a do ano anterior, a calculadora aplica os arts. 12 e 24 da Res. CGSN 140/2018: em
2026, a parte da receita acima do sublimite ou do limite paga pelo percentual maior; acima de
20%, o ICMS e o ISS (e o IBS, a partir de 2027) saem do DAS. Acima de R$ 4.800.000,00 ela
calcula o mês até a exclusão e diz quando a empresa sai do Simples. No ano de início, os dois
são proporcionais aos meses.

**IBS e CBS fora do DAS (2027 em diante):** a empresa que optar pelo regime regular paga o
IBS e a CBS à parte, com créditos (Res. CGSN 140/2018, arts. 22-A e 40-C, na redação da Res.
190/2026). A calculadora tira os dois do DAS e estima o valor com as alíquotas informadas.

Opcional: informe um CNPJ para ver a empresa, o CNAE principal e se ela consta como optante
pelo Simples (dados públicos da Receita Federal, pela BrasilAPI).

**Na página:** o visual segue o do [portfólio](https://pedrassolli.vercel.app) (tema escuro por
padrão, com botão para o claro). O formulário tem uma linha por receita, a chave "Somas dos 12
meses / Mês a mês" e partes opcionais (sublimite, tributos fora do DAS) que abrem sozinhas
quando fazem diferença. Os valores ficam no formato brasileiro ao sair do campo, e "Usar um
exemplo" preenche números fictícios. Se um campo muda depois do cálculo, a página avisa que o
resultado ficou desatualizado.

As tabelas dos Anexos I a V ficam em `data/anexos/2026/` (LC 155/2016) e
`data/anexos/2027-2028/` (LC 214/2025), cada arquivo com o link da fonte oficial, a lei que deu
a redação, a vigência e a data da conferência. Um teste falha se faltar a fonte ou a vigência,
ou se a repartição de uma faixa não somar 100%.

### O que ela não faz

- **Não gera a guia:** é uma estimativa educativa. O valor a pagar é o do PGDAS-D, e a
  responsabilidade pelos dados é da empresa e do contador.
- Não cobre ISS em valor fixo, isenção ou redução de ICMS/ISS dada pelo estado ou município,
  receita com IPI e ISS ao mesmo tempo, nem o limite extra das receitas de exportação.
- Não calcula multa e juros de atraso, substituição tributária ou diferencial de alíquota do
  ICMS, nem o MEI.
- Os tributos fora do DAS são estimativas simples (base × alíquota − créditos; CPP do Anexo IV
  com RAT e FAP informados), sem as regras de cada estado ou município.
- Não aceita meses de 2029 em diante: as tabelas mudam de novo (LC 214/2025).

## Como funciona

```
lib/simples_nacional/   Ruby puro, sem dependências: regras de cada ano, receitas, faixa, Fator R,
                        sublimite e limite, divisão do DAS, fora do DAS e os passos da conta
data/anexos/            tabelas dos Anexos I a V de 2026 e de 2027-2028, com fonte oficial e vigência
data/sublimite.yml      sublimite de cada ano, com o ato e o link
api/calcular.rb         função Ruby da Vercel: recebe os números e devolve o resultado e os passos (JSON)
api/cnpj.rb             consulta opcional de CNPJ pela gem br_validators (BrasilAPI)
web/                    React + Vite, build estático e pré-renderizado (formulário, resultado, memória)
test/                   Minitest, com 100% das linhas cobertas
```

- A regra fica num lugar só, em Ruby testável. A página só mostra o que a API devolve.
- A função da Vercel guarda só o código (sem imagem de container), e a resposta tem
  cache de CDN: o resultado depende só dos números enviados.
- A página é estática e roda com uma Content Security Policy sem `unsafe-inline`.

### A biblioteca

Dinheiro em centavos (Integer) e percentuais em `Rational`, para nenhuma conta passar por Float:

```ruby
require "simples_nacional"

# Duas receitas no mês: revenda com ICMS por substituição tributária e serviços do Anexo III
resultado = SimplesNacional.calcular(periodo: "2026-03", rbt12: 50_000_000, atividades: [
  { tipo: "revenda", receita: 3_000_000, opcoes: ["st_icms"] },
  { tipo: "servicos_3", receita: 1_000_000 }
])
resultado.das                       # => 233944 (R$ 2.339,44)
resultado.atividades.map(&:valor)   # => [134224, 99720]
resultado.passos.map(&:texto)       # a conta explicada, com a base legal de cada passo

# Uma receita só, do jeito antigo (continua valendo)
SimplesNacional.calcular(periodo: "2026-03", rbt12: 50_000_000, receita_mes: 4_000_000, anexo: 3).das # => 398880

# 2027, com o IBS e a CBS fora do DAS e a CBS estimada a 8,8%
resultado = SimplesNacional.calcular(periodo: "2027-03", rbt12: 50_000_000, receita_mes_anterior: 4_000_000,
                                     atividades: [{ tipo: "servicos_3", receita: 4_000_000 }], ibs_cbs_fora: true,
                                     fora_do_das: { aliquota_cbs: Rational(88, 1000) })
resultado.fora_do_das.map { |estimativa| [estimativa.tributo, estimativa.valor] } # => [["IBS", nil], ["CBS", 352000]]
```

### A API

```
GET /api/calcular?periodo=2026-03&rbt12=500000.00&atividades=servicos_3:40000.00
GET /api/calcular?periodo=2026-03&rbt12=500000.00&atividades=revenda:30000.00:st_icms;servicos_3:10000.00
GET /api/calcular?periodo=2026-03&rbt12=500000.00&atividades=fator_r:40000.00&folha12=150000.00
GET /api/calcular?periodo=2026-03&atividades=servicos_4:40000.00&rbt12=500000.00&folha_empregados=30000.00&pro_labore=5000.00&rat=2&fap=1.5
GET /api/calcular?periodo=2027-03&rbt12=500000.00&receita_mes_anterior=40000.00&atividades=servicos_3:40000.00&ibs_cbs_fora=1&aliquota_cbs=8.8
GET /api/calcular?periodo=2026-03&rbt12=500000.00&receita_mes=40000.00&anexo=3
```

Valores em reais, com ponto e até duas casas; meses como `AAAA-MM`; alíquotas em % (`3.5`).

| Parâmetro | O que é |
| --- | --- |
| `periodo` | Mês de apuração, de `2026-01` a `2028-12` |
| `atividades` | Receitas do mês: `tipo:valor:opção+opção`, separadas por `;`. Tipos: `revenda`, `industria`, `servicos_3`, `servicos_4`, `servicos_5`, `fator_r`, `locacao`, `transporte`. Opções: `st_icms`, `monofasico`, `iss_retido`, `exportacao`, `ipi_mantido` (2027 em diante) |
| `anexo` e `receita_mes` | Jeito antigo, com uma receita só (`anexo` de 1 a 5 ou `fator_r`) |
| `rbt12`, `rbt12_exportacao`, `folha12` | Somas dos meses anteriores (com `inicio`, desde o início das atividades) |
| `mes_AAAA-MM` | Mês a mês, no lugar das somas: `receita:exportação:folha` (ex.: `mes_2025-03=41666.66:0:5000`) |
| `inicio` | Mês de início das atividades, para quem ainda não tem 12 meses (13 a partir de 2027) |
| `receita_mes_anterior` | A partir de 2027: receita do mês anterior (fica fora da RBT12) |
| `receita_ano`, `receita_ano_anterior` | Opcionais, para o sublimite e o limite (a API pede quando faz diferença) |
| `ibs_cbs_fora=1` | A partir de 2027: IBS e CBS no regime regular, fora do DAS |
| `aliquota_iss`, `aliquota_icms`, `creditos_icms`, `aliquota_ibs`, `creditos_ibs`, `aliquota_cbs`, `creditos_cbs` | Opcionais, para estimar o que fica fora do DAS |
| `folha_empregados`, `pro_labore`, `rat` (1, 2 ou 3), `fap` (0.5 a 2) | Opcionais, para a CPP do Anexo IV |

A resposta traz `das` e `das_centavos`, `aliquota_efetiva` (média ponderada quando há mais de
uma receita), `rbt12`, `fator_r`, `tributos` (soma de todas as receitas), `atividades` (anexo,
faixa, percentual, valor e tributos de cada receita), `fora_do_das` (tributo, valor ou o dado
que `falta`, texto e fonte), `total_estimado`, `avisos`, os `passos` (com o `grupo` de cada um)
e a `tabela` usada. Os campos de antes (`anexo`, `faixa`, `aliquota_nominal`, `aviso`)
continuam, com os dados da primeira receita. Entrada inválida responde 400 com `erro`.

```
GET /api/cnpj?cnpj=11.222.333/0001-81
```

Consulta opcional: valida o CNPJ com a gem [br_validators](https://rubygems.org/gems/br_validators)
(CNPJ inválido nem chega à internet) e busca na BrasilAPI a razão social, a situação, o CNAE
principal e a opção pelo Simples (`simples.optante`, `desde`, `excluida_em`). Não devolve o
quadro de sócios. O CNAE não escolhe o anexo sozinho: quem decide é a atividade, conforme o
art. 18 da LC 123/2006.

## Fontes oficiais

- [Lei Complementar nº 123/2006, texto compilado (Planalto)](https://www.planalto.gov.br/ccivil_03/leis/lcp/lcp123.htm):
  limites (art. 3º), alíquota efetiva e Fator R (art. 18) e Anexos I a V, com os percentuais
  de repartição (redação da Lei Complementar nº 155/2016, vigência desde 01/01/2018).
  Conferido em 27/10/2026.
- [Resolução CGSN nº 140/2018 (normas da Receita Federal)](https://normas.receita.fazenda.gov.br/sijut2consulta/link.action?idAto=92278):
  percentual efetivo de cada tributo, teto de 5% do ISS e ICMS/ISS na 6ª faixa (art. 21, III),
  RBT12 no início de atividade (art. 22) e folha do Fator R (art. 26). Conferido em 27/10/2026.
- Sublimite: [Portal do Simples Nacional, 2026 (Portaria CGSN nº 54/2025)](https://www8.receita.fazenda.gov.br/SIMPLESNACIONAL/noticias/NoticiaCompleta.aspx?id=94c10cc2-7eb5-4ef0-bfb2-5479e72caff8)
  e [2025 (Portaria CGSN nº 49/2024)](https://www8.receita.fazenda.gov.br/SIMPLESNACIONAL/noticias/NoticiaCompleta.aspx?id=24d7bd11-494d-4ed4-8e28-bb59a8d480e7),
  em `data/sublimite.yml`. Conferido em 27/10/2026.
- [Lei Complementar nº 214/2025 (Planalto)](https://www.planalto.gov.br/ccivil_03/leis/lcp/lcp214.htm):
  Anexos I a V para 2027 e 2028 (Anexos XVIII a XXII, art. 519), em `data/anexos/2027-2028/`.
  Conferido em 02/11/2026.
- [Resolução CGSN nº 190/2026](https://normasinternet2.receita.fazenda.gov.br/#/consulta/externa/152832):
  nova redação da Res. CGSN 140/2018 a partir de 2027 (RBT12, início de atividade, sublimite,
  segregação, IBS e CBS fora do DAS). Conferido em 02/11/2026.
- [Portal do Simples Nacional: opção pelo regime regular do IBS e da CBS para 2027](https://www8.receita.fazenda.gov.br/simplesnacional/noticias/NoticiaCompleta.aspx?id=c739e03c-8482-473f-8e82-f38ec3b13637).

## Rodar na sua máquina

Ruby 3.3 e Node 24 (versões em `.ruby-version` e `web/.nvmrc`).

```bash
bundle install
bundle exec rake test        # testes do Ruby, com cobertura
bundle exec rubocop          # estilo

cd web
npm ci
npm run dev                  # página em http://localhost:5173 (usa a API publicada)
npm test                     # funções do formulário e das chamadas à API
npm run build && npm run test:e2e   # navegador: fluxos, acessibilidade, 320 px e imagens
```

O fluxo de trabalho (cards, branches, PRs, merge automático) está no
[CONTRIBUTING.md](CONTRIBUTING.md).

## Monitoramento

- **Uptime** (`.github/workflows/uptime.yml`): a cada 4 horas e depois de cada deploy de
  produção, confere com `curl` a página, uma conta conhecida em `/api/calcular`, os erros
  esperados das duas funções e os cabeçalhos de segurança. Problema abre uma issue com o
  rótulo `uptime`; deploy de produção com falha abre uma com o rótulo `deploy`. As duas
  fecham sozinhas quando tudo volta.
- **Resumo semanal** no Slack (`#simples`), toda segunda de manhã.
- Diagrama da arquitetura no [FigJam](https://www.figma.com/board/ENcSh8yoOVszzoQbkFY3jA)
  ("Calculadora do Simples Nacional: arquitetura (out/2026)").

## Planos gratuitos

- **GitHub Actions:** repositório público, minutos sem limite. Todo job tem tempo máximo. As
  imagens dos testes visuais só são geradas quando alguém pede (`visual-update.yml`).
- **Vercel Hobby:** só a `main` publica (prévias desligadas) e só quando muda algo que vai
  para o ar (`scripts/vercel-ignorar-build.sh`), porque o espaço de deploys é um só para a
  conta toda.
- **Jira Free:** sem regras de automação; os cards andam pelo `jira.yml`.
- **BrasilAPI:** gratuita e sem chave; as respostas de CNPJ ficam um dia no cache da Vercel.

## Autor

[Pedro Pedrassolli](https://pedrassolli.vercel.app), dev full-stack Ruby on Rails. Usa a gem
[br_validators](https://rubygems.org/gems/br_validators), também dele, na consulta opcional
de CNPJ.

Licença MIT.
