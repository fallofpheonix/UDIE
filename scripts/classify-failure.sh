#!/usr/bin/env bash

LOGS=$(docker logs udie-backend 2>&1)

if echo "$LOGS" | grep -q "ECONNREFUSED"; then
  echo "CLASS: NETWORK / STARTUP_RACE"
elif echo "$LOGS" | grep -q "Cannot GET"; then
  echo "CLASS: API_CONTRACT"
elif echo "$LOGS" | grep -qi "column .* does not exist"; then
  echo "CLASS: SCHEMA_DRIFT"
elif echo "$LOGS" | grep -qi "FAILED"; then
  echo "CLASS: WORKER_FAILURE"
elif echo "$LOGS" | grep -qi "materialization_lag"; then
  echo "CLASS: PROJECTION_LAG"
else
  echo "CLASS: UNKNOWN"
fi
