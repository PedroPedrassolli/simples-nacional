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

Mudou o JSON da API? Atualize `web/e2e/fixtures/`: o teste `test/fixtures_da_pagina_test.rb`
falha enquanto elas forem diferentes da resposta atual.

## Atualizar uma tabela

1. Confira a tabela no texto compilado da Lei Complementar 123/2006 no Planalto.
2. Mude o YAML em `data/anexos/`, com a nova `vigencia`, a lei que deu a redação e a data
   da conferência (`conferido_em`). A `reparticao` de cada faixa vem da tabela "Percentual de
   Repartição dos Tributos" do mesmo anexo e precisa somar 100.00 (o teste confere); na 6ª
   faixa não entra ICMS nem ISS.
3. Abra o PR com o link do trecho da lei na descrição.

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
- O Uptime confere uma conta conhecida (`/api/calcular`, DAS de R$ 3.988,80). Mudou essa conta
  de propósito? Mude o `uptime.yml` no mesmo PR. Atraso de algumas horas nos agendados do
  GitHub é normal.
- O script `.github/scripts/jira-transition.sh` nunca deixa um job vermelho: se o card não
  existe, o Jira não responde ou os secrets faltam, ele só avisa.
- Nunca escreva o marcador que pula a CI (colchetes com "skip ci") numa mensagem de
  commit, nem citado: ele pula a CI do push e do PR, e o PR não entra.
- **Vercel no plano gratuito:** o espaço de deploys (10 GB) é um só para a conta toda.
  - Não há prévia por PR (`git.deploymentEnabled` no `vercel.json`): só a `main` publica.
  - A produção só é publicada quando muda `api/`, `data/`, `lib/`, `web/` (fora os testes),
    o `vercel.json` ou o `Gemfile` (`scripts/vercel-ignorar-build.sh`).
  - A CI cobre o que a prévia conferia: testa a regra, a função e a página no navegador.
  - A Vercel instala o Ruby sem as gems de teste (`BUNDLE_WITHOUT=development:test` nas
    variáveis do projeto).
