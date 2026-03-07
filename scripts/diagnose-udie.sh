#!/usr/bin/env bash
set -e

echo "===== UDIE QUICK DIAGNOSTIC ====="

echo
echo "1. Checking Docker containers"
docker ps --format "table {{.Names}}\t{{.Status}}" | grep -E "udie|postgres|redis" || echo "❌ Containers missing"

echo
echo "2. Checking backend startup"
docker logs udie-backend 2>&1 | grep -m1 "Nest application successfully started" \
  && echo "✅ Backend started" \
  || echo "❌ Backend not started"

echo
echo "3. Detecting API namespace"
API_PREFIX=""
if curl -s http://localhost:3000/api/v1/health >/dev/null 2>&1; then
  API_PREFIX="/api/v1"
elif curl -s http://localhost:3000/api/health >/dev/null 2>&1; then
  API_PREFIX="/api"
else
  echo "❌ API unreachable"
fi

if [ ! -z "$API_PREFIX" ]; then
  echo "✅ API prefix detected: $API_PREFIX"
fi

echo
echo "4. Checking database connectivity"
docker exec udie-postgres pg_isready -U udie >/dev/null 2>&1 \
  && echo "✅ Postgres reachable" \
  || echo "❌ Postgres not reachable"

echo
echo "5. Checking Redis"
docker exec udie-redis redis-cli ping 2>/dev/null | grep PONG \
  && echo "✅ Redis responding" \
  || echo "❌ Redis failure"

echo
echo "6. Checking schema drift"
docker logs udie-backend 2>&1 | grep -i "column\|relation.*does not exist" \
  && echo "❌ Schema drift detected" \
  || echo "✅ No schema errors detected"

echo
echo "7. Checking worker failures"
docker logs udie-backend 2>&1 | grep -i "FAILED\|error" \
  && echo "⚠ Worker errors detected" \
  || echo "✅ Workers healthy"

echo
echo "===== DIAGNOSTIC COMPLETE ====="
