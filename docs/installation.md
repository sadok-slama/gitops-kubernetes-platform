# Installation guide

Goal: run everything on your own machine. Total time: about 45 minutes the first time.
Recommended machine: 4 CPUs and 8 GB RAM free for Minikube (6 GB are given to the cluster by default).

Every important step shows the **expected result** and a **command to check it**.
Commands marked *not run during generation* were written from official documentation but not executed by the author of this repository
(no Docker, Minikube or GitHub access was available): treat the first run as the real test and read
[troubleshooting.md](troubleshooting.md) if a result differs.

## Part A. Windows PowerShell (preparing the machine)

Minikube, Helm and the scripts are Linux tools. On Windows, run them inside **WSL2 Ubuntu**; Docker Desktop provides Docker.

```powershell
# 1. Install WSL2 with Ubuntu (administrator PowerShell). Reboot if asked.
wsl --install -d Ubuntu-24.04
# Check: Ubuntu-24.04 appears with VERSION 2
wsl -l -v

# 2. Install Git and Docker Desktop
winget install --id Git.Git -e
winget install --id Docker.DockerDesktop -e
# Check (after starting Docker Desktop once):
docker version
```

In Docker Desktop: *Settings > Resources > WSL Integration* > enable **Ubuntu-24.04**, then *Apply*.
Open the Ubuntu terminal (`wsl -d Ubuntu-24.04`) and continue with Part B. Work inside the Linux file system
(`~/projects`), not under `/mnt/c`: it is much faster.

Native Linux users skip Part A and install Docker Engine (`sudo apt-get install -y docker.io && sudo usermod -aG docker $USER`, then log out and in).

## Part B. Ubuntu/Linux terminal (tools)

```bash
sudo apt-get update && sudo apt-get install -y curl git make python3 python3-venv yamllint

# kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install kubectl /usr/local/bin/kubectl

# Minikube
curl -LO https://github.com/kubernetes/minikube/releases/latest/download/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube

# Helm 3.19.0 (the version used in CI)
curl -LO https://get.helm.sh/helm-v3.19.0-linux-amd64.tar.gz
tar -xzf helm-v3.19.0-linux-amd64.tar.gz && sudo install linux-amd64/helm /usr/local/bin/helm

# kubeconform 0.6.7 (checksum verified)
curl -sSL -o kubeconform.tgz https://github.com/yannh/kubeconform/releases/download/v0.6.7/kubeconform-linux-amd64.tar.gz
echo "95f14e87aa28c09d5941f11bd024c1d02fdc0303ccaa23f61cef67bc92619d73  kubeconform.tgz" | sha256sum -c -
tar -xzf kubeconform.tgz kubeconform && sudo install kubeconform /usr/local/bin/kubeconform
```

Check (expected: a version for each, no "command not found"; `docker version` must show a Server section):

```bash
docker version && kubectl version --client && minikube version && helm version --short && kubeconform -v && yamllint --version
```

Trivy for local scans is optional (CI always scans). Follow the official installation page for Trivy, or run it as a container:
`docker run --rm -v /var/run/docker.sock:/var/run/docker.sock aquasec/trivy:latest image --severity CRITICAL,HIGH --ignore-unfixed gitops-sample-app:local`.

## Part C. Get the code and run the checks that need no cluster

```bash
git clone https://github.com/<your-user>/gitops-kubernetes-platform.git   # or copy this directory
cd gitops-kubernetes-platform
./scripts/configure-repo.sh <your-github-username>     # replaces YOUR_GITHUB_USERNAME in 3 files
git diff --stat                                        # expected: argocd/application.yaml, argocd/project.yaml, environments/dev/values.yaml
make check
```

Expected from `make check`: `8 passed`, yamllint silent, `1 chart(s) linted, 0 chart(s) failed` twice,
and kubeconform summaries with `Invalid: 0, Errors: 0`.

## Part D. Publish to GitHub (needed for GitOps and CI)

```bash
git add -A && git commit -m "Configure repository for my GitHub account"
git branch -M main && git push -u origin main          # repository must exist on GitHub, branch must be `main`
```

Open the **Actions** tab. Expected: the workflow `CI` runs; after about 3 minutes all five jobs are green,
and a new commit `chore(gitops): deploy <12-char-sha> to dev [skip ci]` appears on `main`.
Then make the package public (see [deployment-workflow.md](deployment-workflow.md#secrets-and-repository-settings)).
Run `git pull` locally to fetch the bot commit.

## Part E. Cluster

```bash
make cluster-up           # starts Minikube profile "gitops", enables metrics-server and ingress
kubectl get nodes         # expected: 1 node, STATUS Ready
```

### Optional smoke test (no GitHub needed, not GitOps)

```bash
make deploy-smoke
make pf-app               # leave running, open a second terminal:
curl localhost:8080/health   # expected: {"status":"ok"}
make clean-smoke          # remove it before the GitOps deployment
```

### Monitoring (install before the app, see [monitoring/README.md](../monitoring/README.md))

```bash
make monitoring-install
kubectl -n monitoring get pods     # expected: all Running / Completed
```

### Argo CD

```bash
make argocd-install
kubectl -n argocd get pods         # expected: all Running
make deploy-gitops                 # registers the AppProject and the Application
kubectl -n argocd get applications # expected within ~3 minutes: sample-app-dev   Synced   Healthy
kubectl -n sample-app-dev get pods # expected: 2 Pods Running (HPA minimum is 2)
```

Argo CD UI: `make pf-argocd`, open https://localhost:8443, user `admin`, password:
`kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d; echo`.

### Test the application

```bash
make pf-app
curl localhost:8080/health      # {"status":"ok"}
curl localhost:8080/version     # JSON whose "commit" equals the full SHA of the commit that was built
```

Optional Ingress (hostname `sample-app.local`): in a separate terminal run `minikube -p gitops tunnel`, then add
`127.0.0.1 sample-app.local` to `/etc/hosts` (WSL users: also to `C:\Windows\System32\drivers\etc\hosts` for a Windows browser).
Port-forward is simpler and enough for this project.

## Part F. See GitOps work end to end

1. Edit `config.APP_MESSAGE` in `helm/sample-app/values-dev.yaml` or change text in `app/src/app.py`, commit, push.
2. Watch **Actions**, then `kubectl -n sample-app-dev get pods -w`.
3. Reload the homepage after a new port-forward (the old one is bound to a replaced Pod).

## Cleanup

```bash
helm uninstall kube-prometheus-stack -n monitoring       # optional, if keeping the cluster
kubectl delete -f argocd/application.yaml                # Argo CD removes the app resources (finalizer)
make cluster-down                                        # deletes the whole Minikube cluster
```
PowerShell, to stop WSL and free memory: `wsl --shutdown`. Delete the GHCR package from your GitHub profile if you no longer need it.
