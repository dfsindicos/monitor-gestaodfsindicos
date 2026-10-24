#!/usr/bin/env bash
# Confere, de fora da VPS, se cada sistema responde 200 em /api/saude. Quem não responde em duas tentativas
# (com ESPERA segundos entre elas) ganha uma issue "Fora do ar: <nome>" com menção ao dono, que avisa por e-mail e
# no app do GitHub; quando volta, a issue recebe o tempo fora do ar e é fechada. A issue aberta é o estado: um aviso
# por queda, nunca um a cada rodada. SITUACAO.md só é reescrito quando algo muda (ou a cada 45 dias, para o GitHub
# não desligar a agenda de um repositório sem commits).
set -euo pipefail
cd "$(dirname "$0")"

ESPERA="${ESPERA:-60}"
AVISAR="${AVISAR:-@dfsindicos}"
ROTULO="fora-do-ar"
agora() { TZ=America/Sao_Paulo date "+%d/%m/%Y %H:%M"; }
codigo() { curl -s -o /dev/null -m 20 -w '%{http_code}' "$1" || true; }

mapfile -t SITES < <(grep -v '^\s*#' sites.txt | grep -v '^\s*$')
declare -A resp
pendentes=()
for s in "${SITES[@]}"; do
  resp["$s"]="$(codigo "${s#*|}")"
  [ "${resp[$s]}" = 200 ] || pendentes+=("$s")
done
if [ "${#pendentes[@]}" -gt 0 ]; then
  sleep "$ESPERA"
  for s in "${pendentes[@]}"; do resp["$s"]="$(codigo "${s#*|}")"; done
fi

gh label create "$ROTULO" --color B42318 --description "Sistema sem resposta em /api/saude" --force >/dev/null
mudou=0
linhas=()
for s in "${SITES[@]}"; do
  nome="${s%%|*}"; url="${s#*|}"; c="${resp[$s]}"
  titulo="Fora do ar: $nome"
  aberta="$(gh issue list --label "$ROTULO" --state open --json number,title --jq "map(select(.title == \"$titulo\"))[0].number // empty")"
  if [ "$c" != 200 ]; then
    linhas+=("| $nome | fora do ar (resposta $c) |")
    if [ -z "$aberta" ]; then
      gh issue create --label "$ROTULO" --title "$titulo" --body "$AVISAR o **$nome** não respondeu em duas tentativas, com $ESPERA s entre elas.

- Endereço conferido: $url
- Resposta: \`$c\` (\`000\` = sem resposta)
- Detectado em: $(agora) (Brasília)

Se todos os sistemas caíram juntos, a VPS pode estar travada: https://hpanel.hostinger.com/vps
Esta issue é fechada sozinha quando o sistema voltar, com o tempo fora do ar." >/dev/null
      echo "caiu: $nome ($c)"; mudou=1
    fi
  else
    linhas+=("| $nome | no ar |")
    if [ -n "$aberta" ]; then
      desde="$(gh issue view "$aberta" --json createdAt --jq .createdAt)"
      minutos=$(( ( $(date +%s) - $(date -d "$desde" +%s) ) / 60 ))
      gh issue comment "$aberta" --body "Voltou: respondeu 200 em $(agora) (Brasília). Fora do ar por cerca de $minutos min." >/dev/null
      gh issue close "$aberta" >/dev/null
      echo "voltou: $nome ($minutos min)"; mudou=1
    fi
  fi
done

ultimo="$(git log -1 --format=%ct 2>/dev/null || echo 0)"
velho=$(( $(date +%s) - ultimo > 45 * 86400 ))
[ "$mudou" = 1 ] || [ "$velho" = 1 ] || { echo "sem mudança"; exit 0; }

{
  echo "# Situação dos sistemas DF"
  echo
  echo "Atualizado em $(agora) (Brasília). Conferência a cada 5 minutos pelo workflow \"Monitor\"."
  echo
  echo "| Sistema | Agora |"
  echo "|---|---|"
  printf '%s\n' "${linhas[@]}"
  echo
  echo "## Últimas quedas"
  echo
  TZ=America/Sao_Paulo gh issue list --label "$ROTULO" --state all --limit 20 --json title,createdAt,closedAt,url \
    --jq '.[] | "- \(.title | sub("^Fora do ar: "; "")): \(.createdAt | fromdate | strflocaltime("%d/%m/%Y %H:%M")) até \(if .closedAt then (.closedAt | fromdate | strflocaltime("%d/%m %H:%M")) else "agora" end) · \(.url)"'
} > SITUACAO.md
git config user.name "github-actions[bot]"
git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
git add SITUACAO.md
git commit -qm "Atualizar a situação dos sistemas" && git push -q
