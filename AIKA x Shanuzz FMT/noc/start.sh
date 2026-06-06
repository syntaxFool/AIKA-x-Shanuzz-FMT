#!/bin/bash
# Start PocketBase server for AIKA x Shanuzz FMT
# Usage: ./start.sh [port]

PORT=${1:-8090}
DIR="$(cd "$(dirname "$0")" && pwd)"
exec "$DIR/pocketbase" serve --dir="$DIR/pb_data" --http="127.0.0.1:$PORT"
