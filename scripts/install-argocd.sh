#!/usr/bin/env bash
# Install Argo CD (pinned version) from the official manifest and wait until it is ready.
# Usage: ./scripts/install-argocd.sh
set -euo pipefail

ARGOCD_VERSION="${ARGOCD_VERSION:-v3.5.6}"
NAMESPACE="argocd"

command -v kubectl >/dev/null 2>&1 || { echo "ERROR: kubectl is not installed." >&2; exit 1; }
kubectl cluster-info >/dev/null 2>&1 || { echo "ERROR: no reachable cluster. Run scripts/setup-minikube.sh first." >&2; exit 1; }

echo ">> Installing Argo CD ${ARGOCD_VERSION} in namespace ${NAMESPACE}"
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
# --server-side is required: the ApplicationSet CRD is too large for client-side apply annotations.
kubectl apply -n "$NAMESPACE" --server-side --force-conflicts \
  -f "https://raw.githubusercontent.com/argoproj/argo-cd/${ARGOCD_VERSION}/manifests/install.yaml"

echo ">> Waiting for Argo CD deployments to become available (up to 5 minutes)"
kubectl -n "$NAMESPACE" wait --for=condition=Available deployment --all --timeout=300s
kubectl -n "$NAMESPACE" rollout status statefulset/argocd-application-controller --timeout=300s

echo ">> Argo CD pods"
kubectl -n "$NAMESPACE" get pods
cat <<MSG

Argo CD is installed. To open the UI:
  kubectl -n argocd port-forward svc/argocd-server 8443:443
  then browse https://localhost:8443 (accept the self-signed certificate), user: admin
Initial admin password:
  kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d; echo
MSG
