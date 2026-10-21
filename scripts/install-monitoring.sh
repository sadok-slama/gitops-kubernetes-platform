#!/usr/bin/env bash
# Install kube-prometheus-stack (Prometheus + Grafana) in the 'monitoring' namespace.
set -euo pipefail

CHART_VERSION="${KPS_CHART_VERSION:-92.11.0}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

for tool in helm kubectl; do
  command -v "$tool" >/dev/null 2>&1 || { echo "ERROR: '$tool' is not installed." >&2; exit 1; }
done

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts --force-update
helm repo update
helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --version "$CHART_VERSION" \
  --namespace monitoring --create-namespace \
  -f "$ROOT/monitoring/values.yaml" \
  --wait --timeout 10m

kubectl -n monitoring get pods
