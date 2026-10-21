# Troubleshooting

General method: `kubectl get` the object, then `kubectl describe` it (read the **Events** at the bottom), then `kubectl logs`.

| Symptom | Likely cause | Check / fix |
|---|---|---|
| `minikube start` fails with Docker errors | Docker not running, or not enough memory | `docker info`; lower `MINIKUBE_MEMORY=4096 ./scripts/setup-minikube.sh`; WSL: enable Docker Desktop WSL integration |
| Pod `ImagePullBackOff` / `ErrImagePull` | Tag `initial` still in `environments/dev/values.yaml` (CI has not run), wrong username, or private GHCR package | `kubectl -n sample-app-dev describe pod <pod>`; check the Actions run and `git pull`; make the package public or add `imagePullSecrets` |
| Pod `CrashLoopBackOff` | Application error | `kubectl -n sample-app-dev logs deploy/sample-app --previous` |
| Pod `Running` but not `Ready` | Readiness probe failing | `describe pod`; the probe calls `/health` on container port 8080 |
| `CreateContainerConfigError` mentioning non-root | Image user is not numeric | The Dockerfile uses `USER 10001:10001`; rebuild the image if changed |
| Argo CD app `OutOfSync` / error `repository not found` | Placeholder not replaced, repository private, or branch is not `main` | `kubectl -n argocd describe application sample-app-dev`; run `scripts/configure-repo.sh`; add repository credentials in Argo CD |
| Argo CD error: resource not permitted by project | Chart creates a kind that `argocd/project.yaml` does not whitelist | Add the group/kind to `namespaceResourceWhitelist`, commit, `kubectl apply -f argocd/project.yaml` |
| Argo CD error `no matches for kind ServiceMonitor` | Monitoring stack not installed yet | `make monitoring-install`; the retry policy then succeeds, or click *Sync* |
| `kubectl apply` of Argo CD fails with "annotations too long" | Client-side apply of large CRDs | Use `scripts/install-argocd.sh` (it uses `--server-side`) |
| Argo CD does not react immediately | Default polling interval of about 3 minutes | Click *Refresh* in the UI, or `kubectl -n argocd annotate application sample-app-dev argocd.argoproj.io/refresh=hard --overwrite` |
| HPA shows `<unknown>/70%` | metrics-server not ready | `minikube -p gitops addons enable metrics-server`; `kubectl top pods -A` after a minute |
| Trivy step fails in CI | A fixable HIGH/CRITICAL vulnerability was found | Read the table in the log; update the base image or dependency (Dependabot may already have a PR); never disable the scan to get green |
| Trivy step fails with `TOOMANYREQUESTS` | Rate limit when downloading the vulnerability database | Re-run the job later |
| CI `update-gitops` fails with `protected branch` or 403 | Branch protection or read-only workflow permissions | See *Limitation* in [deployment-workflow.md](deployment-workflow.md) |
| CI push to GHCR fails with 403 | Package already exists linked to another repository or user | In package settings, add this repository under *Manage Actions access* with Write role |
| Grafana login rejected | Wrong password | Read it with the command in [monitoring/README.md](../monitoring/README.md) |
| Target not shown in Prometheus | ServiceMonitor absent or label mismatch | `kubectl -n sample-app-dev get servicemonitor,svc --show-labels`; the Service must carry `app.kubernetes.io/name=sample-app` |
| `port-forward` stops after a deployment | The forwarded Pod was replaced | Forward the Service (`svc/sample-app`) and restart the command |
| WSL: very slow commands | Project stored under `/mnt/c` | Move it into the Linux file system (`~/projects`) |
| `make: *** missing separator` | Tabs turned into spaces in the Makefile | Recipes must start with a TAB character |

Useful commands:

```bash
kubectl get events -A --sort-by=.lastTimestamp | tail -20
kubectl -n argocd logs deploy/argocd-repo-server | tail -30     # rendering / Git errors
kubectl -n argocd get application sample-app-dev -o yaml | less # status.conditions explains sync failures
helm template sample-app helm/sample-app -f helm/sample-app/values-dev.yaml -f environments/dev/values.yaml   # what Argo CD would render
```
