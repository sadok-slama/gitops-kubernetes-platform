# Screenshots

This folder is meant for **genuine** screenshots taken from your own running environment. None are included on purpose:
a screenshot proves something only if you captured it.

Capture these after completing [docs/installation.md](../installation.md), and save them with these names
(the main README references them once they exist):

| File | What to capture | How |
|---|---|---|
| `argocd-synced.png` | Argo CD UI, application `sample-app-dev` showing **Synced** and **Healthy** with the resource tree | `make pf-argocd`, open https://localhost:8443 |
| `app-homepage.png` | Application homepage showing the commit SHA | `make pf-app`, open http://localhost:8080 |
| `github-actions-run.png` | A green run of the CI workflow, all jobs visible | GitHub > Actions tab |
| `grafana-namespace-pods.png` | Grafana dashboard *Kubernetes / Compute Resources / Namespace (Pods)* with namespace `sample-app-dev` | `make pf-grafana` |
| `prometheus-targets.png` | Prometheus *Status > Targets* with the `sample-app` target UP | `make pf-prometheus` |
| `kubectl-rollout.png` | Terminal output of `kubectl -n sample-app-dev get pods` during a rollout | terminal |

Tips: crop out browser bookmarks, tokens, and any password field. Never publish the Argo CD admin password or a kubeconfig.
After adding them, embed in the README with `![Argo CD synced](docs/screenshots/argocd-synced.png)`.
