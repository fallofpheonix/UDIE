#!/bin/sh
set -eu

echo "host replication replicator all scram-sha-256" >> "${PGDATA}/pg_hba.conf"
echo "host all all all scram-sha-256" >> "${PGDATA}/pg_hba.conf"
