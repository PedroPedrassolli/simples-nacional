# Como contribuir

## Fluxo

1. Toda mudança começa num card do Jira (projeto **SIMP**).
2. Crie a branch a partir da `main` com a chave do card: `simp-3-descricao-curta`.
   O card vai sozinho para "Em andamento".
3. Abra o PR com o título começando pela chave: `SIMP-3: descrição curta`.
   O card vai para "Em análise".
4. Quando a CI passa e o PR está atualizado com a `main`, ele é mesclado sozinho
   (`.github/workflows/auto-merge.yml`) e o card vai para "Concluído".
   Para segurar um PR, abra como rascunho ou use o rótulo `segurar`.

PR de fork não é mesclado sozinho: precisa de revisão.

## Regras do código

- Código simples, que um dev júnior entenda. Comentários em português explicando o porquê.
- Sem abstração "para o futuro": só o que o card pede.
- A regra fica em `lib/`, em Ruby puro e sem dependências. A página não recalcula nada:
  mostra o que a API devolve.
- **Toda regra fiscal vem da fonte oficial**, com o link e a data da conferência no
  código ou no YAML (Lei Complementar 123/2006 no Planalto, Portal do Simples Nacional,
  Receita Federal). Nada de número de memória ou de blog.
- Valores em dinheiro e percentuais sem `Float` (use `Rational` ou centavos inteiros),
  para a conta não errar no arredondamento.
- Dados de exemplo sempre fictícios.
- Cobertura de 100% das linhas do Ruby (o `test/test_helper.rb` cobra isso).

## Comandos

| Comando | Para quê |
| --- | --- |
| `bundle exec rake test` | Testes do Ruby, com cobertura |
| `bundle exec rubocop` | Estilo do Ruby |
| `cd web && npm run dev` | Página em `localhost:5173`; `/api` vai para a API publicada |
| `cd web && npm test` | Funções puras do formulário (`node --test`) |
| `cd web && npm run lint` | ESLint da página |
| `cd web && npm run format:check` | Prettier da página e do `vercel.json` |
| `cd web && npm run build && npm run test:e2e` | Playwright + axe com a API simulada (temas claro e escuro, 320 px) |
| `cd web && npx @lhci/cli@0.15.1 autorun` | Lighthouse no build (`web/dist`), como na CI |

Mudou o JSON da API? O teste `test/fixtures_da_pagina_test.rb` falha enquanto as respostas
guardadas em `web/e2e/fixtures/` forem diferentes. Para regravar: `ATUALIZAR_FIXTURES=1 bundle
exec rake test`, depois `cd web && npx prettier --write e2e/fixtures`, e confira o diff.

## Testes visuais

`web/e2e/visual.spec.js` compara a página com as imagens de `web/e2e/visual.spec.js-snapshots/`
(início nos dois temas, resultado com duas receitas, mês a mês e fora do DAS no celular, os
campos de fora do DAS abertos no celular e no computador, o MEI, as situações com atraso e a
memória de cálculo impressa). As imagens dependem do sistema e do navegador, por isso são
geradas na CI, nunca na sua máquina:

1. Mudou o visual de propósito? Ponha o rótulo `atualizar-imagens` no PR (ou rode o workflow
   "Imagens dos testes visuais" à mão, na branch).
2. O workflow faz o commit das imagens na branch e tira o rótulo. Confira as imagens no PR.
3. Faça mais um push na branch: o commit do workflow não dispara a CI (é do `GITHUB_TOKEN`).

## Onde fica cada regra

| Arquivo em `lib/simples_nacional/` | O que faz |
| --- | --- |
| `regras.rb` | O que muda de 2026 para 2027 e 2028 (e de onde vêm as tabelas de cada ano) |
| `entrada.rb`, `atividades.rb`, `atividades_informadas.rb`, `historico.rb` | Confere o que chegou: receitas do mês (com isenção e redução), somas ou mês a mês |
| `inicio_de_atividade.rb`, `acumulados.rb`, `fator_r.rb` | RBT12 e folha anualizadas, e o Fator R |
| `sublimite.rb`, `limite.rb`, `limite_da_exportacao.rb` | Receita do ano, sublimite, limite (e o limite extra da exportação) e exclusão |
| `valores_fixos.rb` | ICMS e ISS em valor fixo (e os avisos do art. 33 da Res. CGSN 140/2018) |
| `atraso.rb` | Vencimento, multa e juros do DAS pago em atraso (Selic em `data/selic.yml`) |
| `mei.rb`, `passos_do_mei.rb` | O DAS do MEI e o limite do ano (valores em `data/mei.yml`) |
| `apuracao_da_atividade.rb`, `reparticao.rb` | Faixa, alíquota efetiva e divisão de cada receita |
| `fora_do_das.rb`, `fora_do_das_estimativas.rb`, `fora_do_das_do_icms.rb` | ISS, ICMS, ICMS-ST, DIFAL, IBS, CBS e CPP pagos à parte |
| `calculo.rb` | Junta tudo e soma o DAS |
| `passos*.rb`, `passo_*.rb`, `avisos.rb` | Os textos da conta passo a passo e os avisos |

## Atualizar uma tabela

1. Confira a tabela no texto compilado da Lei Complementar 123/2006 no Planalto.
2. Mude o YAML em `data/anexos/<ano>/` (`2026` ou `2027-2028`), com a nova `vigencia`, a lei que deu a redação e a data
   da conferência (`conferido_em`). A `reparticao` de cada faixa vem da tabela "Percentual de
   Repartição dos Tributos" do mesmo anexo e precisa somar 100.00 (o teste confere); na 6ª
   faixa não entra ICMS nem ISS.
3. Abra o PR com o link do trecho da lei na descrição.

## Atualizar o sublimite

Todo fim de ano o Comitê Gestor divulga o sublimite do ano seguinte (notícia no Portal do
Simples Nacional e portaria no DOU). Acrescente o ano em `data/sublimite.yml` com o ato e o
link. Se algum estado adotar R$ 1.800.000,00, o arquivo é recusado de propósito: a conta muda
(4ª faixa, Res. CGSN 140/2018, art. 24, I, b, 1) e o formulário passa a precisar da UF.
A partir de 2027 o valor está na própria Res. CGSN 140/2018 (art. 9º, redação da Res. CGSN
190/2026), sem portaria anual. A página usa o mesmo valor (`SUBLIMITE` em `web/src/periodos.js`) só para abrir os campos
opcionais na hora certa; um teste confere que ele bate com o YAML.

## Selic e salário mínimo

- **Selic (juros do atraso):** o workflow `selic.yml` roda no dia 3 de cada mês (ou à mão, em
  Actions → Selic → Run workflow), baixa a série 4390 do Banco Central, regrava o
  `data/selic.yml`, roda os testes e faz o commit na `main` só se entrou um mês novo. O commit
  publica a API (o `data/` vai para o ar). Se o mês ainda não saiu, a API calcula sem ele e avisa.
- **Salário mínimo (MEI):** sai num decreto em dezembro. Acrescente o ano em `data/mei.yml`
  (valor, ato e link do Planalto). Enquanto o ano não estiver lá, a página pede o valor.

## Cuidados

- A CI roda em todo PR, inclusive nos que só mudam arquivos `.md`: o merge automático
  espera sempre a CI do commit.
- Merge feito pelo `GITHUB_TOKEN` não dispara outros workflows. Por isso o
  `auto-merge.yml` move o card do Jira ele mesmo.
- Workflows disparados por `workflow_run` ou `status` (Auto-merge, Uptime) usam a versão que
  está na `main`. Se você mudar o
  `auto-merge.yml`, abra o PR como rascunho: até o merge, quem decide é a versão antiga.
- As Actions dos workflows ficam fixadas pelo commit (SHA), com a versão num comentário.
  Não troque por `@v7`: uma tag pode ser movida para outro código. O Dependabot atualiza.
- A página é pré-renderizada no build (`web/scripts/prerender.mjs`): o HTML já sai pronto e o
  React só hidrata. O primeiro desenho do `App` precisa ser igual no build e no navegador:
  nada de `window`, data atual ou número aleatório durante o render (use `useEffect`).
- O visual segue o do portfólio: as cores e medidas do topo do `web/src/estilo.css` são as do
  `frontend/src/styles/tokens.css` do repositório `portfolio`, e o cabeçalho, os botões, os
  cartões e o rodapé repetem os componentes de lá. Mudou a identidade no portfólio? Mude aqui
  também. O tema vem do `data-theme` do `<html>` (escuro por padrão; `public/theme.js` aplica o
  salvo antes de pintar), não do tema do sistema.
- Layout da página: no computador, só o formulário e o resultado ficam lado a lado. O que
  abre e fecha e pode crescer (passo a passo, consulta de CNPJ) vai em largura total, embaixo
  (`.layout` no `estilo.css`); senão uma coluna fica muito mais alta que a outra. Mudou o visual?
  Confira com as partes abertas em 320 px e em 1280 px, nos dois temas.
- Fontes: os arquivos da Geist ficam em `web/public/fontes/` (licença OFL junto), com
  `font-display: optional` e preload no `index.html`. Com o `swap` do pacote, a troca de fonte
  depois da primeira pintura empurrava a calculadora (CLS 0,103 no Lighthouse da CI, que só
  aparecia lá: o resumo do Lighthouse lista o que se deslocou e por quê).
- A CSP da página não permite `style` inline. Largura que depende de dado (as barras da
  divisão do DAS) vai como atributo de SVG, não como `style={{ width }}`.
- Os tipos de receita e as situações especiais do formulário (`web/src/atividades.js`) resumem
  o art. 18 da LC 123/2006 e o art. 25 da Res. CGSN 140/2018, com a data em que foram
  conferidos. Os códigos são os de `lib/simples_nacional/atividades.rb` (um teste confere).
  Mudou a lei? Confira as dicas junto com as tabelas.
- O Uptime confere uma conta conhecida (`/api/calcular`, março de 2026, DAS de R$ 3.988,80).
  Mudou essa conta ou os parâmetros obrigatórios de propósito? Mude o `uptime.yml` no mesmo PR.
  Atraso de algumas horas nos agendados do GitHub é normal.
- A calculadora aceita meses de 2026 a 2028 (`Regras::ANOS`). Para 2029 entram outras tabelas
  da LC 214/2025: não basta acrescentar o ano. O mês e o ano ficam em duas listas na página
  (`ANOS` em `web/src/periodos.js`).
- Os campos de fora do DAS ficam numa grade com `subgrid` (`.grade` no `estilo.css`): o rótulo,
  a caixa e o erro de um campo ficam alinhados com os do vizinho. Cada tributo é um `fieldset`
  com legenda, então o campo pode ter um nome curto ("MVA", "Alíquota própria"). Um teste de
  320 px confere o alinhamento e que o "%" fica dentro da caixa.
- O script `.github/scripts/jira-transition.sh` nunca deixa um job vermelho: se o card não
  existe, o Jira não responde ou os secrets faltam, ele só avisa.
- O `rodape-pr.yml` tira sozinho do corpo de PRs e comentários o rodapé que ferramentas
  acrescentam ao criar o texto pela API. Não precisa editar à mão.
- `overrides.minimatch` no `web/package.json`: o ESLint 10 ainda pede o minimatch 10, que tem um
  alerta moderado do Dependabot ([GHSA-g3hv-75wg-m249](https://github.com/advisories/GHSA-g3hv-75wg-m249)),
  só na ferramenta de lint (não vai para o site). Quando o ESLint passar a pedir o 11, tire o override.
- Arquivos com acento (fixtures, YAML) são lidos com `encoding: "UTF-8"`: sem isso, numa
  máquina sem locale UTF-8 o Ruby lê em US-ASCII e o teste quebra no primeiro "ç".
- Nunca escreva o marcador que pula a CI (colchetes com "skip ci") numa mensagem de
  commit, nem citado: ele pula a CI do push e do PR, e o PR não entra.
- **Vercel no plano gratuito:** o espaço de deploys (10 GB) é um só para a conta toda.
  - Não há prévia por PR (`git.deploymentEnabled` no `vercel.json`): só a `main` publica.
  - A produção só é publicada quando muda `api/`, `data/`, `lib/`, `web/` (fora os testes),
    o `vercel.json` ou o `Gemfile` (`scripts/vercel-ignorar-build.sh`).
  - A CI cobre o que a prévia conferia: testa a regra, a função e a página no navegador.
  - A Vercel instala o Ruby sem as gems de teste (`BUNDLE_WITHOUT=development:test` nas
    variáveis do projeto).
