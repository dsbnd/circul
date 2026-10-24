#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
RUN_DIR="$PROJECT_DIR/.run/cloud"

CONFIG_PORT="${CONFIG_PORT:-18330}"
EUREKA_PORT="${EUREKA_PORT:-18430}"
TICKET_PORT="${TICKET_PORT:-18030}"
GATEWAY_PORT="${GATEWAY_PORT:-18530}"
BOOKING_LOAD_BALANCER_PORT="${BOOKING_LOAD_BALANCER_PORT:-18130}"

CONFIG_JAR="$PROJECT_DIR/config-server/target/config-server-1.0.0.jar"
EUREKA_JAR="$PROJECT_DIR/eureka-server/target/eureka-server-1.0.0.jar"
TICKET_JAR="$PROJECT_DIR/ticket-service/target/ticket-service-1.0.0.war"
GATEWAY_JAR="$PROJECT_DIR/api-gateway/target/api-gateway-1.0.0.jar"

JAVA_OPTS=(
    -Xms32m
    -Xmx128m
    -XX:MaxMetaspaceSize=128m
    -Xss256k
    -XX:ActiveProcessorCount=1
    -XX:+UseSerialGC
    --add-opens=java.base/java.lang=ALL-UNNAMED
)

mkdir -p "$RUN_DIR"

cleanup_on_error() {
    "$SCRIPT_DIR/stop-cloud-helios.sh" >/dev/null 2>&1 || true
}

trap cleanup_on_error ERR

port_is_busy() {
    local port="$1"
    (echo >/dev/tcp/127.0.0.1/"$port") >/dev/null 2>&1
}

require_artifacts() {
    local missing=0
    local artifact
    for artifact in "$CONFIG_JAR" "$EUREKA_JAR" "$TICKET_JAR" "$GATEWAY_JAR"; do
        if [[ ! -r "$artifact" ]]; then
            echo "Не найден $artifact" >&2
            missing=1
        fi
    done
    if ((missing)); then
        echo "Сначала выполните ./scripts/build-cloud.sh" >&2
        exit 1
    fi
}

check_ports() {
    local busy=()
    local port
    for port in "$CONFIG_PORT" "$EUREKA_PORT" "$TICKET_PORT" "$GATEWAY_PORT"; do
        if port_is_busy "$port"; then
            busy+=("$port")
        fi
    done
    if ((${#busy[@]})); then
        echo "Порты уже заняты: ${busy[*]}" >&2
        echo "Выполните ./scripts/stop-cloud-helios.sh и повторите запуск." >&2
        exit 1
    fi
}

wait_for_health() {
    local name="$1"
    local url="$2"
    local pid="$3"
    local log_file="$4"

    for _ in {1..120}; do
        if curl -fsS --max-time 2 "$url" >/dev/null 2>&1; then
            echo "$name запущен (PID $pid)."
            return
        fi
        if ! kill -0 "$pid" 2>/dev/null; then
            echo "$name завершился с ошибкой." >&2
            tail -80 "$log_file" >&2
            exit 1
        fi
        sleep 1
    done

    echo "$name не успел запуститься." >&2
    tail -80 "$log_file" >&2
    exit 1
}

start_service() {
    local id="$1"
    local name="$2"
    local jar="$3"
    local health_url="$4"
    shift 4

    local log_file="$RUN_DIR/$id.log"
    local pid_file="$RUN_DIR/$id.pid"
    : >"$log_file"

    nohup java "${JAVA_OPTS[@]}" -jar "$jar" "$@" \
        >"$log_file" 2>&1 &
    local pid=$!
    echo "$pid" >"$pid_file"
    wait_for_health "$name" "$health_url" "$pid" "$log_file"
}

require_artifacts
check_ports

export CONFIG_REPOSITORY="file:$PROJECT_DIR/config-repo"
export CONFIG_SERVER_URL="http://127.0.0.1:$CONFIG_PORT"
export EUREKA_SERVER_URL="http://127.0.0.1:$EUREKA_PORT/eureka/"
export BOOKING_LOAD_BALANCER_URL="http://127.0.0.1:$BOOKING_LOAD_BALANCER_PORT"

start_service config "Config Server" "$CONFIG_JAR" \
    "http://127.0.0.1:$CONFIG_PORT/actuator/health" \
    --server.address=127.0.0.1 \
    --server.port="$CONFIG_PORT"

start_service eureka "Eureka Server" "$EUREKA_JAR" \
    "http://127.0.0.1:$EUREKA_PORT/actuator/health" \
    --server.address=127.0.0.1 \
    --server.port="$EUREKA_PORT"

start_service ticket "Ticket Service" "$TICKET_JAR" \
    "http://127.0.0.1:$TICKET_PORT/api/v1/actuator/health" \
    --server.address=127.0.0.1 \
    --server.port="$TICKET_PORT"

start_service gateway "Zuul API Gateway" "$GATEWAY_JAR" \
    "http://127.0.0.1:$GATEWAY_PORT/actuator/health" \
    --server.address=127.0.0.1 \
    --server.port="$GATEWAY_PORT"

trap - ERR

echo
echo "Config Server: http://127.0.0.1:$CONFIG_PORT"
echo "Eureka Server: http://127.0.0.1:$EUREKA_PORT"
echo "Ticket direct: http://127.0.0.1:$TICKET_PORT/api/v1"
echo "Public API:    http://127.0.0.1:$GATEWAY_PORT/api/v1"
