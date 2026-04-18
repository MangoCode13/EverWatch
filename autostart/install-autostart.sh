#!/usr/bin/env bash
set -euo pipefail

SERVICE_NAME="everwatch-compose.service"
SRC_SERVICE="/home/CYSE587student/EverWatch/autostart/${SERVICE_NAME}"
DST_SERVICE="/etc/systemd/system/${SERVICE_NAME}"

if [[ ! -f "${SRC_SERVICE}" ]]; then
  echo "Service file not found: ${SRC_SERVICE}" >&2
  exit 1
fi

sudo systemctl enable docker
sudo systemctl enable containerd
sudo cp "${SRC_SERVICE}" "${DST_SERVICE}"
sudo systemctl daemon-reload
sudo systemctl enable "${SERVICE_NAME}"
sudo systemctl start "${SERVICE_NAME}"

sudo systemctl status "${SERVICE_NAME}" --no-pager
