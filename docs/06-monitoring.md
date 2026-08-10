# Monitoring & Logging Guide

## Table of Contents
1. [Prometheus & Grafana Setup](#prometheus--grafana-setup)
2. [Loki Stack Setup](#loki-stack-setup)
3. [Dashboard Configuration](#dashboard-configuration)
4. [Log Queries](#log-queries)
5. [Alerting Rules](#alerting-rules)
6. [Verification & Resource Usage](#verification--resource-usage)

## Prometheus & Grafana Setup
Install the `kube-prometheus-stack` using Helm:
```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm install prometheus prometheus-community/kube-prometheus-stack \
  -n monitoring --create-namespace \
  -f gitops/infra/monitoring/prometheus-values.yaml
```

## Loki Stack Setup
Install Loki and Promtail for logging:
```bash
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update
helm install loki grafana/loki-stack \
  -n monitoring \
  -f gitops/infra/monitoring/loki-values.yaml
```

## Dashboard Configuration

### Access Grafana
Port-forward to access Grafana (if Ingress is not set up yet):
```bash
kubectl port-forward svc/prometheus-grafana -n monitoring 3000:80
```
- Username: `admin`
- Password: `prom-operator` (or as defined in your values).

### Import Dashboards
1. Navigate to **Dashboards -> Import**.
2. Import the following standard dashboards via ID:
   - **7249**: Kubernetes Cluster Monitoring
   - **1860**: Node Exporter Full

### Configure Loki Datasource
1. Go to **Connections -> Data sources -> Add data source**.
2. Select **Loki**.
3. HTTP URL: `http://loki:3100`
4. Click **Save & Test**.

## Log Queries
To view application logs via Explore -> Loki:
```logql
{namespace="devops-project"}
```
Filter for backend errors:
```logql
{namespace="devops-project", app="backend"} |= "error"
```

## Alerting Rules
The following custom rules are configured in `prometheus-values.yaml` for Alertmanager:
- **PodRestarts**: Triggers if a pod restarts > 3 times within 15 minutes.
- **HighCPUUsage**: Triggers if node CPU usage > 80% for 5 minutes.
- **HighMemoryUsage**: Triggers if node Memory > 85% for 5 minutes.
- **HighErrorRate**: Triggers if backend API 5xx error rate > 5% over 5 minutes.

## Verification & Resource Usage

### Verify Targets
In Prometheus (`kubectl port-forward svc/prometheus-kube-prometheus-prometheus 9090:9090`), navigate to **Status -> Targets** and ensure standard endpoints are "UP".

### Kubernetes Resource Commands
Monitor node and pod metrics quickly via CLI:
```bash
kubectl top nodes
kubectl top pods -n devops-project
```
