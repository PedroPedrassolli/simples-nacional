#!/usr/bin/env bash
# Move um card do Jira para outro status, pela API REST do Jira.
# Usado por .github/workflows/jira.yml (no lugar das regras de automação do Jira,
# que no plano Free têm só 150 passos por mês).
#
# Uso: jira-transition.sh CHAVE "Status de destino" categorias-permitidas
#   ex.: jira-transition.sh SIMP-3 "Em análise" "new,indeterminate"
# Categorias do status atual (do Jira): new = A fazer, indeterminate = em andamento,
# done = concluído/cancelado. Se o card estiver numa categoria fora da lista,
# nada é feito (ex.: nunca reabrir um card concluído).
#
# Mover o card é um extra: quando algo dá errado (card que não existe, Jira fora
# do ar, transição que não existe), o script só avisa e termina com sucesso, para
# não deixar a CI ou o merge automático vermelhos por causa do Jira.
#
# Precisa de JIRA_EMAIL e JIRA_API_TOKEN (secrets do GitHub) e JIRA_SITE.
set -euo pipefail

key="$1"
target="$2"
allowed="$3"

warn() {
  echo "::warning title=Jira::$1"
  exit 0
}

if [ -z "${JIRA_EMAIL:-}" ] || [ -z "${JIRA_API_TOKEN:-}" ]; then
  warn "Secrets JIRA_EMAIL e JIRA_API_TOKEN ausentes; o card $key não foi movido."
fi

jira() {
  curl --silent --show-error --fail \
    --user "$JIRA_EMAIL:$JIRA_API_TOKEN" \
    -H "Accept: application/json" -H "Content-Type: application/json" \
    "$@"
}

issue="https://$JIRA_SITE/rest/api/3/issue/$key"

response=$(jira "$issue?fields=status") || warn "Não deu para ler o card $key (não existe ou o Jira não respondeu)."
current_name=$(jq -r .fields.status.name <<<"$response")
current_category=$(jq -r .fields.status.statusCategory.key <<<"$response")

if [ "$current_name" = "$target" ]; then
  echo "$key já está em \"$target\"."
  exit 0
fi

# "Cancelado" fica na categoria "new" no Jira, mas é decisão final: nunca sai dele sozinho.
if [ "$current_name" = "Cancelado" ]; then
  echo "$key está cancelado; não move."
  exit 0
fi

if [[ ",$allowed," != *",$current_category,"* ]]; then
  echo "$key está em \"$current_name\" ($current_category); não move para \"$target\"."
  exit 0
fi

transitions=$(jira "$issue/transitions") || warn "Não deu para ler as transições do card $key."
transition=$(jq -r --arg target "$target" '.transitions[] | select(.to.name == $target) | .id' <<<"$transitions" | head -n 1)

[ -n "$transition" ] || warn "Não há transição de \"$current_name\" para \"$target\" no card $key."

jira -X POST "$issue/transitions" --data "{\"transition\":{\"id\":\"$transition\"}}" > /dev/null ||
  warn "O Jira recusou mover o card $key para \"$target\"."
echo "::notice title=Jira::$key: \"$current_name\" → \"$target\""
