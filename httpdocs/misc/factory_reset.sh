#!/bin/bash

if [ "$EUID" -ne 0 ]; then
  echo "Please run this script as root"
  exit 1
fi

echo "Removing contents of /var/lib/ntopng/..."
rm -rf /var/lib/ntopng/*
echo "ntopng data removed."

NTOPNG_KEYS=$(redis-cli --raw keys "ntopng.*" | wc -l)
if [ "$NTOPNG_KEYS" -gt 1 ]; then
  echo "Flushing Redis ($NTOPNG_KEYS keys)..."
  redis-cli --raw keys "ntopng.*" | xargs -n 100 redis-cli del >/dev/nul
  echo "Redis flushed."
else
  echo "No ntopng-related keys found in Redis. Skipping flush."
fi

check_clickhouse_installed() {
    command -v clickhouse-client >/dev/null 2>&1
}

CLICKHOUSE=0
HOST=""
USER=""
PASS=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    -c|--clickhouse)
      CLICKHOUSE=1
      shift
      ;;
    -h|--host)
      HOST="$2"
      shift 2
      ;;
    -u|--user)
      USER="$2"
      shift 2
      ;;
    -p|--password)
      PASS="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

if [ "$CLICKHOUSE" -eq 1 ]; then
    if check_clickhouse_installed; then

        echo "Dropping ntopng database from ClickHouse..."
        CMD=("clickhouse-client")
        if [ -n "$HOST" ]; then
            CMD+=(--host="$HOST")
        fi
        if [ -n "$USER" ]; then
            CMD+=(--user="$USER")
        fi
        if [ -n "$PASS" ]; then
            CMD+=(--password="$PASS")
        fi
        CMD+=(--query="DROP DATABASE IF EXISTS ntopng")

        "${CMD[@]}"

        if [ $? -eq 0 ]; then
            echo "ClickHouse database ntopng dropped."
        else
            echo "Failed to drop ClickHouse database."
        fi
    else
        echo "ClickHouse is not installed."
    fi
else
    echo "Skipping ClickHouse operations."
fi