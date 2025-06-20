#!/bin/bash

if [ "$EUID" -ne 0 ]; then
  echo "Please run this script as root"
  exit 1
fi

echo "Removing contents of /var/lib/ntopng/..."
rm -rf /var/lib/ntopng/*
echo "ntopng data removed."

echo "Flushing Redis..."
redis-cli flushall
echo "Redis flushed."

check_clickhouse_installed() {
    command -v clickhouse-client >/dev/null 2>&1
}

if check_clickhouse_installed; then
    echo "Dropping ntopng database from ClickHouse..."
    clickhouse-client --query="DROP DATABASE IF EXISTS ntopng"
    echo "ClickHouse database ntopng dropped."
else
    echo "ClickHouse is not installed."
fi

echo "All operations completed."