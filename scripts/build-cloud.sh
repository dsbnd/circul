#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
MAVEN_ARGS=()

if [[ -n "${MAVEN_REPO_LOCAL:-}" ]]; then
    MAVEN_ARGS+=("-Dmaven.repo.local=$MAVEN_REPO_LOCAL")
fi

build() {
    local module="$1"
    echo "Сборка $module..."
    mvn "${MAVEN_ARGS[@]}" -f "$PROJECT_DIR/$module/pom.xml" clean package
}

build config-server
build eureka-server
build ticket-service
build api-gateway

echo "Spring Cloud-компоненты собраны."
