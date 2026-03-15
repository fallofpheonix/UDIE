#!/bin/sh
set -eu

export PGDATA="${PGDATA:-/var/lib/postgresql/data}"

if [ ! -s "${PGDATA}/PG_VERSION" ]; then
  rm -rf "${PGDATA:?}"/*
  until pg_isready -h "${PRIMARY_HOST}" -p "${PRIMARY_PORT:-5432}" -U "${REPLICATION_USER}"; do
    sleep 2
  done
  export PGPASSWORD="${REPLICATION_PASSWORD}"
  pg_basebackup \
    -h "${PRIMARY_HOST}" \
    -p "${PRIMARY_PORT:-5432}" \
    -U "${REPLICATION_USER}" \
    -D "${PGDATA}" \
    -Fp \
    -R \
    -Xs \
    -P
fi

exec postgres -c hot_standby=on
