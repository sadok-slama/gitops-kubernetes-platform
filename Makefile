# GitOps Kubernetes Platform - developer shortcuts. Run `make help`.
PROFILE   ?= gitops
HELM      ?= helm
KUBECONFORM ?= kubeconform
K8S_VERSION_SCHEMA ?= 1.31.0
CRD_SCHEMA = https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json
VENV      = app/.venv
DEV_VALUES = -f helm/sample-app/values-dev.yaml -f environments/dev/values.yaml

.DEFAULT_GOAL := help
.PHONY: help venv test lint-yaml lint-helm validate build scan check cluster-up argocd-install monitoring-install \
        deploy-smoke deploy-gitops pf-app pf-argocd pf-grafana pf-prometheus clean-smoke cluster-down

help: ## Show this help
	grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-20s %s\n", $$1, $$2}'

venv: ## Create the Python virtualenv and install dependencies
	python3 -m venv $(VENV)
	$(VENV)/bin/pip install -q -r app/requirements-dev.txt

test: venv ## Run the unit tests
	cd app && .venv/bin/python -m pytest -v

lint-yaml: ## yamllint on all YAML files
	yamllint -c .yamllint.yaml .

lint-helm: ## helm lint (default and dev values)
	$(HELM) lint helm/sample-app
	$(HELM) lint helm/sample-app $(DEV_VALUES)

validate: ## Render the chart and validate manifests with kubeconform
	$(HELM) template sample-app helm/sample-app --namespace sample-app-dev | $(KUBECONFORM) -strict -summary -kubernetes-version $(K8S_VERSION_SCHEMA) -schema-location default -schema-location '$(CRD_SCHEMA)' -
	$(HELM) template sample-app helm/sample-app --namespace sample-app-dev $(DEV_VALUES) | $(KUBECONFORM) -strict -summary -kubernetes-version $(K8S_VERSION_SCHEMA) -schema-location default -schema-location '$(CRD_SCHEMA)' -
	$(KUBECONFORM) -strict -summary -schema-location default -schema-location '$(CRD_SCHEMA)' argocd/project.yaml argocd/application.yaml

build: ## Build the Docker image locally (gitops-sample-app:local)
	docker build -t gitops-sample-app:local --build-arg GIT_SHA=local app

scan: build ## Scan the local image with Trivy (requires trivy installed)
	trivy image --severity CRITICAL,HIGH --ignore-unfixed --exit-code 1 gitops-sample-app:local

check: test lint-yaml lint-helm validate ## Run every check that needs no cluster and no Docker

cluster-up: ## Start Minikube and enable addons
	./scripts/setup-minikube.sh

argocd-install: ## Install Argo CD in the cluster
	./scripts/install-argocd.sh

monitoring-install: ## Install kube-prometheus-stack (Prometheus + Grafana)
	./scripts/install-monitoring.sh

deploy-smoke: ## Build the image in Minikube and install the chart directly with Helm (not GitOps)
	./scripts/deploy-local.sh smoke

deploy-gitops: ## Register the Argo CD project and application
	./scripts/deploy-local.sh gitops

pf-app: ## Port-forward the application on http://localhost:8080
	kubectl -n sample-app-dev port-forward svc/sample-app 8080:80

pf-argocd: ## Port-forward the Argo CD UI on https://localhost:8443
	kubectl -n argocd port-forward svc/argocd-server 8443:443

pf-grafana: ## Port-forward Grafana on http://localhost:3000
	kubectl -n monitoring port-forward svc/kube-prometheus-stack-grafana 3000:80

pf-prometheus: ## Port-forward Prometheus on http://localhost:9090
	kubectl -n monitoring port-forward svc/kube-prometheus-stack-prometheus 9090:9090

clean-smoke: ## Remove the Helm smoke-test release
	$(HELM) uninstall sample-app -n sample-app-dev

cluster-down: ## Delete the Minikube cluster and everything in it
	minikube delete -p $(PROFILE)
