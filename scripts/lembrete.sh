#!/usr/bin/env bash
# Envia alerta pelo ntfy a cada execução (cron de 15 min) enquanto o suplemento do dia não for marcado.
# A marca "creatina-AAAA-MM-DD" é publicada no tópico "<TOPIC>-ok" pela página tomei.html.
set -euo pipefail
export TZ=America/Sao_Paulo
[ -n "${TOPIC:-}" ] || { echo "Segredo NTFY_TOPIC não configurado"; exit 0; }

NTFY=https://ntfy.sh
CFG=lembretes.json
PAGINA="https://isantodev.github.io/ficha/tomei.html"
hoje=$(date +%F)
agora=$(date +%H:%M)
feitos=$(curl -fsS "$NTFY/$TOPIC-ok/json?poll=1&since=24h" || true)

for k in $(jq -r 'keys[]' "$CFG"); do
  ini=$(jq -r ".\"$k\".inicio" "$CFG"); fim=$(jq -r ".\"$k\".fim" "$CFG"); titulo=$(jq -r ".\"$k\".titulo" "$CFG")
  marca="$k-$hoje"
  quando=$(printf '%s\n' "$feitos" | jq -r --arg m "$marca" 'select(.message == $m) | .time' 2>/dev/null | tail -1)
  if [ -n "$quando" ]; then
    # o ntfy.sh guarda mensagens por 12 h; renova a marca para ela valer até o fim do dia
    if [ $(( $(date +%s) - quando )) -gt 21600 ]; then curl -fsS -d "$marca" "$NTFY/$TOPIC-ok" >/dev/null; fi
    echo "$k: já tomado hoje"; continue
  fi
  if [[ "$agora" < "$ini" || ! "$agora" < "$fim" ]]; then echo "$k: fora do horário"; continue; fi

  min=$(( ( $(date +%s) - $(date -d "$hoje $ini" +%s) ) / 60 ))
  aviso=$(( min / 15 + 1 ))
  prioridade=4; [ "$min" -ge 60 ] && prioridade=5
  if [ "$aviso" -le 1 ]; then msg="Hora de tomar. Toque em Tomei para marcar e parar os alertas de hoje."
  else msg="Ainda não marcado (${aviso}º aviso). Toque em Tomei quando tomar."; fi
  link="$PAGINA?k=$k&t=$TOPIC"
  curl -fsS "$NTFY/$TOPIC" \
    -H "Title: $titulo" -H "Priority: $prioridade" -H "Tags: pill" \
    -H "Click: $link" -H "Actions: view, Tomei, $link, clear=true" \
    -d "$msg" >/dev/null
  echo "$k: alerta $aviso enviado"
done
