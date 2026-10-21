#!/usr/bin/env bash
# Start a local Minikube cluster and enable the addons used by this project.
# Usage: ./scripts/setup-minikube.sh            (defaults below can be overridden with env vars)
set -euo pipefail

PROFILE="${MINIKUBE_PROFILE:-gitops}"
CPUS="${MINIKUBE_CPUS:-4}"
MEMORY="${MINIKUBE_MEMORY:-6144}"          # MiB
K8S_VERSION="${K8S_VERSION:-stable}"       # e.g. v1.31.0 to pin a version

for tool in docker minikube kubectl; do
  command -v "$tool" >/dev/null 2>&1 || { echo "ERROR: '$tool' is not installed (see docs/installation.md)." >&2; exit 1; }
done
docker info >/dev/null 2>&1 || { echo "ERROR: the Docker daemon is not reachable. Start Docker first." >&2; exit 1; }

echo ">> Starting Minikube profile '${PROFILE}' (${CPUS} CPUs, ${MEMORY} MiB)"
minikube start -p "$PROFILE" --driver=docker --cpus="$CPUS" --memory="$MEMORY" --kubernetes-version="$K8S_VERSION"

echo ">> Enabling addons: metrics-server (needed by the HPA), ingress (optional Ingress)"
minikube -p "$PROFILE" addons enable metrics-server
minikube -p "$PROFILE" addons enable ingress

kubectl config use-context "$PROFILE" >/dev/null

echo ">> Cluster status"
kubectl get nodes
echo "Done. Expected: one node in STATUS 'Ready'."
