#!/usr/bin/env bash
# Two ways to run the application on Minikube:
#   ./scripts/deploy-local.sh smoke   Build the image inside Minikube and install the chart with Helm.
#                                     Quick test of app + chart. This is NOT GitOps.
#   ./scripts/deploy-local.sh gitops  Register the AppProject and Application in Argo CD.
#                                     Argo CD then deploys from your GitHub repository (GitOps).
set -euo pipefail

MODE="${1:-}"
PROFILE="${MINIKUBE_PROFILE:-gitops}"
NAMESPACE="sample-app-dev"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

usage() { echo "Usage: $0 {smoke|gitops}" >&2; exit 1; }
[ -n "$MODE" ] || usage

case "$MODE" in
  smoke)
    for tool in docker minikube helm kubectl; do
      command -v "$tool" >/dev/null 2>&1 || { echo "ERROR: '$tool' is not installed." >&2; exit 1; }
    done
    echo ">> Building image 'gitops-sample-app:local' inside Minikube"
    minikube -p "$PROFILE" image build -t gitops-sample-app:local --build-arg GIT_SHA=local "$ROOT/app"
    echo ">> Installing the Helm chart (release 'sample-app', namespace ${NAMESPACE})"
    helm upgrade --install sample-app "$ROOT/helm/sample-app" \
      --namespace "$NAMESPACE" --create-namespace \
      --set image.repository=gitops-sample-app --set image.tag=local --set image.pullPolicy=Never \
      --set config.APP_ENVIRONMENT=smoke-test \
      --wait --timeout 3m
    kubectl -n "$NAMESPACE" get pods,svc
    cat <<MSG

Test it:
  kubectl -n ${NAMESPACE} port-forward svc/sample-app 8080:80
  curl http://localhost:8080/health      # expected: {"status":"ok"}
Remove it:
  helm uninstall sample-app -n ${NAMESPACE}
MSG
    ;;
  gitops)
    command -v kubectl >/dev/null 2>&1 || { echo "ERROR: kubectl is not installed." >&2; exit 1; }
    if grep -q "YOUR_GITHUB_USERNAME" "$ROOT/argocd/application.yaml" "$ROOT/argocd/project.yaml"; then
      echo "ERROR: placeholders not replaced. Run ./scripts/configure-repo.sh <github-user>, commit and push first." >&2
      exit 1
    fi
    kubectl apply -f "$ROOT/argocd/project.yaml"
    kubectl apply -f "$ROOT/argocd/application.yaml"
    echo ">> Application registered. Check with:"
    echo "   kubectl -n argocd get applications"
    echo "   kubectl -n ${NAMESPACE} get pods"
    ;;
  *) usage ;;
esac
