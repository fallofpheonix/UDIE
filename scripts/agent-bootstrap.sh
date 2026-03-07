#!/bin/bash
# UDIE Agent Bootstrap & Verification Script
# This script enforces the mandatory diagnostic protocol for AI agents and engineers.

set -e

echo "🚀 Starting UDIE Agent Bootstrap..."

# 1. Diagnostic Execution
echo "--- [1/5] Running Core Diagnostics ---"
chmod +x ./scripts/diagnose-udie.sh ./scripts/classify-failure.sh
./scripts/diagnose-udie.sh

# 2. API Contract & Metadata
echo "--- [2/5] Metadata Discovery ---"
GIT_HASH=$(git rev-parse --short HEAD 2>/dev/null || echo "not-a-git-repo")
DB_VER=$(docker exec udie-postgres psql -U udie -d udie -t -c "SELECT version();" | head -n 1 | xargs)
echo "Commit: $GIT_HASH"
echo "Database: $DB_VER"

# 3. Automated Classification
echo "--- [3/5] Automatic Failure Check ---"
./scripts/classify-failure.sh

# 4. Environment Snapshot
echo "--- [4/5] Snapshoting Topology ---"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Health}}"

# 5. Reproduction Mandate
echo "--- [5/5] REPRODUX MANDATE ---"
echo "⚠️  You must now record a reproduction of the reported issue."
echo "✅ Bootstrap Complete. System is ready for deterministic engineering."
