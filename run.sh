#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

COMPOSE_FILE="compose.dev.yml"
CMD="${1:-up}"

case "$CMD" in
  up)
    rm -f tmp/pids/server.pid
    docker compose -f "$COMPOSE_FILE" up "${@:2}"
    ;;
  build)
    docker compose -f "$COMPOSE_FILE" up --build "${@:2}"
    ;;
  down)
    docker compose -f "$COMPOSE_FILE" down "${@:2}"
    ;;
  logs)
    docker compose -f "$COMPOSE_FILE" logs -f "${@:2}"
    ;;
  sh|shell|bash)
    docker compose -f "$COMPOSE_FILE" exec web bash
    ;;
  setup)
    docker compose -f "$COMPOSE_FILE" run --rm web bin/setup
    ;;
  *)
    docker compose -f "$COMPOSE_FILE" "$@"
    ;;
esac
