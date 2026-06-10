# Stage 6 — Prometheus + Grafana Monitoring

> **Status:** Implemented — run bootstrap on Jenkins EC2, then redeploy backend via Jenkins.

## What was added

| Component | Path |
|-----------|------|
| Helm values (kube-prometheus-stack) | `k8s/monitoring/values-prometheus-stack.yaml` |
| Bootstrap script | `scripts/bootstrap-monitoring.sh` |
| Backend metrics (`prom-client`) | `backend/src/metrics.ts`, `GET /metrics` |
| ServiceMonitor | `k8s/monitoring/servicemonitor-backend.yaml` |
| Alert rules | `k8s/monitoring/prometheus-rules-todo-app.yaml` |
| Custom dashboard | `k8s/monitoring/dashboards/todo-app-overview.json` |

## One-time setup (Jenkins EC2)

### Step 1 — Push code and redeploy backend

On your laptop:

```powershell
cd C:\Users\sourabh\Desktop\todo-app\backend
npm install
cd ..
git add .
git commit -m "Add Prometheus metrics and Grafana monitoring stack"
git push origin main
```

Wait for Jenkins pipeline to finish (backend must expose `/metrics`).

### Step 2 — Install monitoring stack

SSH to Jenkins EC2:

```bash
cd ~/todo-app
git pull
chmod +x scripts/bootstrap-monitoring.sh
./scripts/bootstrap-monitoring.sh
```

This installs Prometheus, Grafana, Alertmanager, node-exporter, and kube-state-metrics in the `monitoring` namespace.

### Step 3 — Open Grafana

```bash
kubectl get svc kube-prometheus-stack-grafana -n monitoring
```

Open the **EXTERNAL-IP** URL in your browser.

| Field | Value |
|-------|--------|
| User | `admin` |
| Password | `changeme-grafana-admin` |

Change the password after first login.

### Step 4 — Open dashboards

In Grafana → **Dashboards**:

- **Todo App Overview** (custom — auto-loaded)
- Import built-in dashboards by ID: **315** (K8s cluster), **6417** (pods), **1860** (node)

### Step 5 — Verify metrics

```bash
# Prometheus targets (backend should be UP)
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
# Open http://localhost:9090/targets

# Generate traffic
NLB=$(kubectl get svc frontend -n todo-app -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
for i in $(seq 1 30); do curl -s "http://${NLB}/api/todos" >/dev/null; done
```

Watch **Backend request rate** move on the Todo App Overview dashboard.

## Alerts

View fired alerts:

```bash
kubectl port-forward -n monitoring svc/kube-prometheus-stack-alertmanager 9093:9093
# Open http://localhost:9093
```

| Alert | Meaning |
|-------|---------|
| TodoBackendDown | No backend pods ready |
| TodoFrontendDown | No frontend pods ready |
| TodoPodCrashLooping | Restarts spiking |
| TodoHighErrorRate | >5% HTTP 5xx |
| TodoNodeHighCPU | Worker node CPU >85% |
| TodoPodMemoryHigh | Pod using >80% memory limit |

## Metrics exposed by backend

| Metric | Description |
|--------|-------------|
| `http_requests_total` | Request count by method, route, status |
| `http_request_duration_seconds` | Latency histogram |
| `todo_operations_total` | create / update / delete counts |
| `nodejs_*` | Node.js process metrics (heap, event loop) |

## Resource note

Monitoring adds ~1.5–2 GB RAM on your `t3.medium` worker. If pods stay Pending/OOMKilled, bump the node to `t3.large` in Terraform or reduce Prometheus retention in `values-prometheus-stack.yaml`.

## Troubleshoot

| Problem | Fix |
|---------|-----|
| Backend target DOWN in Prometheus | Redeploy backend via Jenkins; curl backend pod `/metrics` |
| No Todo App dashboard | Re-run bootstrap script (ConfigMap + label `grafana_dashboard=1`) |
| Grafana LB pending | Wait 2–3 min; check `kubectl get svc -n monitoring` |
| Helm install timeout | `kubectl get pods -n monitoring`; retry bootstrap script |

## Optional next steps

- Loki + Promtail for logs in Grafana
- Slack/email receivers in Alertmanager
- HPA using these metrics (Stage 7)
