# Monitoring: Prometheus + Grafana (kube-prometheus-stack)

The `kube-prometheus-stack` Helm chart installs Prometheus, the Prometheus Operator, Grafana,
kube-state-metrics, node-exporter and a set of ready-made Kubernetes dashboards.
Chart version pinned in this project: **92.11.0** (app version v0.94.1 of the operator; requires Kubernetes >= 1.25).
Settings for Minikube are in [`values.yaml`](values.yaml).

## 1. Install (Ubuntu/Linux terminal)

Install it **before** letting Argo CD sync the application: the app chart creates a `ServiceMonitor`,
a custom resource that only exists once this stack has installed its CRDs.

```bash
./scripts/install-monitoring.sh          # or: make monitoring-install
kubectl -n monitoring get pods           # expected: all pods Running (takes 2-5 minutes)
```

## 2. Open Grafana

```bash
# Read the generated admin password (not stored in Git)
kubectl -n monitoring get secret kube-prometheus-stack-grafana -o jsonpath='{.data.admin-password}' | base64 -d; echo
make pf-grafana                          # = kubectl -n monitoring port-forward svc/kube-prometheus-stack-grafana 3000:80
```

Browse http://localhost:3000, user `admin`.

## 3. What to inspect

Dashboards (menu *Dashboards*) that ship with the stack:

- **Kubernetes / Compute Resources / Namespace (Pods)**: choose namespace `sample-app-dev` to see CPU and memory of the application Pods.
- **Kubernetes / Compute Resources / Cluster**: global view of the Minikube node.
- **Node Exporter / Nodes**: node CPU, memory, disk, network.

Dashboard names can change between chart versions; use the search box if one is missing.

## 4. Confirm that the application is monitored

The application exposes real Prometheus metrics on `/metrics` (`sample_app_http_requests_total` and
`sample_app_http_request_duration_seconds`, implemented in `app/src/app.py`). The chart creates a `ServiceMonitor`
when `metrics.serviceMonitor.enabled=true` (set in `helm/sample-app/values-dev.yaml`).

```bash
kubectl -n sample-app-dev get servicemonitor                 # expected: sample-app
make pf-prometheus                                           # then open http://localhost:9090
```

In Prometheus, open **Status > Targets** (http://localhost:9090/targets): a target named
`serviceMonitor/sample-app-dev/sample-app/0` should be **UP**. Then try in the **Graph** tab:

```promql
up{namespace="sample-app-dev"}
sum(rate(sample_app_http_requests_total[5m])) by (path, status)
histogram_quantile(0.95, sum(rate(sample_app_http_request_duration_seconds_bucket[5m])) by (le))
```

Generate traffic first, otherwise the rate queries stay empty:

```bash
make pf-app                       # in a first terminal
for i in $(seq 1 50); do curl -s localhost:8080/health > /dev/null; done   # in a second terminal
```

Kubernetes components are monitored by the stack's own ServiceMonitors: **Status > Targets** lists kubelet, apiserver,
kube-state-metrics and node-exporter. The etcd, scheduler, controller-manager and kube-proxy monitors are disabled
in `values.yaml` because Minikube does not expose those endpoints to Prometheus.

## Limits

- No custom Grafana dashboard for the application is provided; use the PromQL queries above in Grafana *Explore*.
- Alertmanager is disabled, and Prometheus keeps only 24 hours of data with no persistent volume tuning: demo settings.
