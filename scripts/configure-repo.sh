#!/usr/bin/env bash
# Replace the YOUR_GITHUB_USERNAME placeholder with your GitHub username (run once, then commit).
# Usage: ./scripts/configure-repo.sh <github-username>
set -euo pipefail

if [ $# -ne 1 ] || [ -z "$1" ]; then
  echo "Usage: $0 <github-username>" >&2
  exit 1
fi

USER_NAME="$1"
USER_LC="$(printf '%s' "$USER_NAME" | tr '[:upper:]' '[:lower:]')"   # GHCR image names must be lowercase
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Repository URLs keep the exact case of the username; image names use lowercase.
sed -i "s|github.com/YOUR_GITHUB_USERNAME/|github.com/${USER_NAME}/|g" \
  "$ROOT/argocd/application.yaml" "$ROOT/argocd/project.yaml"
sed -i "s|ghcr.io/YOUR_GITHUB_USERNAME/|ghcr.io/${USER_LC}/|g" \
  "$ROOT/environments/dev/values.yaml"

echo "Placeholders replaced. Remaining occurrences (expected: none in the files below):"
grep -rn "YOUR_GITHUB_USERNAME" "$ROOT/argocd" "$ROOT/environments" || echo "  none"
echo "Now review with 'git diff', then commit and push."
