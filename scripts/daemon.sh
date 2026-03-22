#!/bin/bash
set -euo pipefail

DATA_DIR="${HOME}/.wechat-claude-code"
SERVICE_NAME="wechat-claude-code"
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"

install_service() {
  NODE_BIN="$(command -v node || echo '/usr/local/bin/node')"
  mkdir -p "$DATA_DIR/logs"

  cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=WeChat Claude Code Bridge
After=network.target

[Service]
Type=simple
User=${USER}
WorkingDirectory=${PROJECT_DIR}
ExecStart=${NODE_BIN} ${PROJECT_DIR}/dist/main.js start
Restart=always
RestartSec=5
StandardOutput=append:${DATA_DIR}/logs/stdout.log
StandardError=append:${DATA_DIR}/logs/stderr.log
Environment=PATH=${NODE_BIN%/*}:/usr/local/bin:/usr/bin:/bin
Environment=HOME=${HOME}
Environment=ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY:-}

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  systemctl enable "$SERVICE_NAME"
  echo "Service installed: $SERVICE_FILE"
}

case "${1:-}" in
  start)
    if [ ! -f "$SERVICE_FILE" ]; then
      install_service
    fi
    systemctl start "$SERVICE_NAME"
    echo "Started $SERVICE_NAME"
    ;;
  stop)
    systemctl stop "$SERVICE_NAME" 2>/dev/null || true
    echo "Stopped $SERVICE_NAME"
    ;;
  restart)
    systemctl restart "$SERVICE_NAME"
    echo "Restarted $SERVICE_NAME"
    ;;
  status)
    systemctl status "$SERVICE_NAME" --no-pager
    ;;
  install)
    install_service
    echo "Run 'npm run daemon -- start' to start the service"
    ;;
  uninstall)
    systemctl stop "$SERVICE_NAME" 2>/dev/null || true
    systemctl disable "$SERVICE_NAME" 2>/dev/null || true
    rm -f "$SERVICE_FILE"
    systemctl daemon-reload
    echo "Service uninstalled"
    ;;
  logs)
    LOG_DIR="${DATA_DIR}/logs"
    if systemctl list-units --full -all 2>/dev/null | grep -q "$SERVICE_NAME"; then
      journalctl -u "$SERVICE_NAME" -n 100 --no-pager
    elif [ -d "$LOG_DIR" ]; then
      for f in "${LOG_DIR}/stdout.log" "${LOG_DIR}/stderr.log"; do
        if [ -f "$f" ]; then
          echo "=== $(basename "$f") ==="
          tail -50 "$f"
        fi
      done
    else
      echo "No logs found"
    fi
    ;;
  *)
    echo "Usage: daemon.sh {start|stop|restart|status|install|uninstall|logs}"
    ;;
esac
