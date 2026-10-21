# Deployment workflow

## The six steps

1. **Developer changes code** in `app/` and opens a pull request.
2. **GitHub Actions** (`.github/workflows/ci.yaml`) runs on the pull request: unit tests, yamllint, `helm lint`,
   `helm template` + kubeconform, Docker build, Trivy scan. Nothing is published from a pull request.
3. After the merge to `main`, the same checks run again; when all pass, the **publish** job pushes
   `ghcr.io/<owner>/gitops-sample-app:<first 12 chars of the commit SHA>`.
4. The **update-gitops** job edits one line (`tag:`) in `environments/dev/values.yaml` and commits it to `main`
   as `github-actions[bot]` with the message `chore(gitops): deploy <tag> to dev [skip ci]`.
5. **Argo CD** polls the repository (default every 3 minutes), sees the new commit, renders the chart with the new tag
   and syncs the cluster. Automated sync with `prune` and `selfHeal` is enabled in `argocd/application.yaml`.
6. **Kubernetes** performs a rolling update: with `maxSurge: 1` and `maxUnavailable: 0` a new Pod starts, must pass the
   readiness probe on `/health`, and only then is an old Pod removed.

## How the image tag is updated (and why)

The pipeline writes the tag into Git instead of calling the cluster. Git therefore holds the single source of truth,
the history of deployments is the history of commits, and a rollback is a `git revert`.

Why this simple approach: one `sed` on one line, no extra controller. Alternatives (Argo CD Image Updater, Flux image
automation, Kustomize `edit set image`) add components to learn and operate; they become worthwhile with many services.

Security properties:

- Immutable tags: the commit SHA is unique, `latest` is never published or deployed.
- Least privilege: only the `update-gitops` job has `contents: write`; only `publish` has `packages: write`.
  The default token permission is `contents: read`.
- No loop: the commit uses `[skip ci]`, `environments/**` is in `paths-ignore`, and commits made with the built-in
  `GITHUB_TOKEN` do not trigger workflows anyway.
- Concurrent merges: the `gitops-update` concurrency group serialises the updates, and the job runs `git pull --rebase` first.

Limitation: if you protect `main` with a rule requiring pull requests, the bot cannot push directly. Options: allow
`github-actions[bot]` to bypass the rule, or change the job to open a pull request (for example with
`peter-evans/create-pull-request`) and merge it after review, which adds a human approval before deployment.

## Secrets and repository settings

This project needs **no manually created secret**:

| Need | How it is provided |
|---|---|
| Push to GHCR | The built-in `secrets.GITHUB_TOKEN` with `packages: write` in the publish job |
| Commit the new tag | The same token with `contents: write` in the update job |

Required settings (repository > Settings):

1. *Actions > General > Workflow permissions*: leave "Read repository contents" as default; the workflow raises permissions per job.
   If your organization forces read-only tokens, allow "Read and write permissions" for the update to work.
2. After the first successful publish, open your profile > *Packages* > `gitops-sample-app` > *Package settings* >
   set visibility to **Public** (simplest for Minikube). To keep it private, create a read-only personal access token with
   `read:packages`, then `kubectl -n sample-app-dev create secret docker-registry ghcr-pull --docker-server=ghcr.io --docker-username=<user> --docker-password=<token>`
   and set `imagePullSecrets: [{name: ghcr-pull}]` in `environments/dev/values.yaml`. Never commit that token.
3. If your repository is private, Argo CD also needs read access: add the repository in the Argo CD UI
   (*Settings > Repositories*) with a fine-grained token limited to *Contents: read-only*.

If you later add a registry other than GHCR, store its credentials in *Settings > Secrets and variables > Actions* and
reference them as `${{ secrets.NAME }}` in the login step. Never write them in a file.

## Watching a deployment

```bash
kubectl -n argocd get applications                      # SYNC STATUS: Synced, HEALTH STATUS: Healthy
kubectl -n sample-app-dev rollout status deployment/sample-app
kubectl -n sample-app-dev get pods -w                   # old Pods replaced one by one
kubectl -n sample-app-dev get deployment sample-app -o jsonpath='{.spec.template.spec.containers[0].image}'; echo
curl -s localhost:8080/version                          # after `make pf-app`; "commit" must start with the new tag
```

To see Git-driven self-healing: `kubectl -n sample-app-dev scale deployment sample-app --replicas=5` is reverted by Argo CD
(or governed by the HPA when autoscaling is enabled, which is why the chart omits `replicas` in that case).

## Rollback

```bash
git revert <commit-that-changed-the-tag>   # or revert the application commit
git push origin main
```
Argo CD syncs the previous tag. Avoid `kubectl rollout undo`: selfHeal would fight it, because Git still says the new version.
