#!/usr/bin/env bash
# One-time install on the Jenkins/Minikube EC2 host (run as root).
# Makes http://<EC2_PUBLIC_IP>:30060/ survive Jenkins builds (Restart=always).
set -euo pipefail

UNIT_SRC="$(cd "$(dirname "$0")" && pwd)/simplecasio-port-forward.service"
UNIT_DST=/etc/systemd/system/simplecasio-port-forward.service

if [[ ! -f "${UNIT_SRC}" ]]; then
  echo "Missing ${UNIT_SRC}"
  exit 1
fi

install -m 644 "${UNIT_SRC}" "${UNIT_DST}"
systemctl daemon-reload
systemctl enable --now simplecasio-port-forward.service
systemctl status --no-pager simplecasio-port-forward.service || true

echo ""
echo "Installed. Keep SG TCP 30060 open, then browse http://<EC2_PUBLIC_IP>:30060/"
echo "Allow jenkins passwordless restart (optional, for pipeline):"
echo "  echo 'jenkins ALL=(root) NOPASSWD: /bin/systemctl start simplecasio-port-forward.service, /bin/systemctl stop simplecasio-port-forward.service, /bin/systemctl restart simplecasio-port-forward.service, /bin/systemctl is-active simplecasio-port-forward.service, /bin/systemctl status simplecasio-port-forward.service' > /etc/sudoers.d/jenkins-simplecasio-pf"
echo "  chmod 440 /etc/sudoers.d/jenkins-simplecasio-pf"
