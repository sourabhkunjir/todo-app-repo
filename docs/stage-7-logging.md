# Stage 7 — Loki Logging in Grafana

> **Status:** Implemented — push code, redeploy backend, run bootstrap on Jenkins EC2.

## What was added

| Component | Purpose |
|-----------|---------|
| **Loki** | Stores log lines from all pods |
| **Promtail** | DaemonSet — collects stdout/stderr from Kubernetes containers |
| **Loki datasource** | Auto-loaded into existing Grafana |
| **Todo App Logs dashboard** | 13 panels — volume, errors, live tail, HTTP, todos, nginx, DB |
| **morgan** (backend) | HTTP access log every request → visible in Loki |
| **`[TODO]` / `[ERROR]` / `[DB]` tags** | Easy LogQL filtering |

## Architecture

```
backend/frontend pods (stdout)
        ↓
Promtail (on worker node)
        ↓
Loki (monitoring namespace)
        ↓
Grafana (same UI as Prometheus dashboards)
```

---

## Setup steps

### Step 1 — Push all files to GitHub (laptop)

```powershell
cd C:\Users\sourabh\Desktop\todo-app\backend
npm install
cd ..
git add .
git commit -m "Add Loki logging stack and rich backend logs for Grafana"
git push origin main
```

Includes: `k8s/logging/`, `scripts/bootstrap-logging.sh`, backend logging changes.

### Step 2 — Wait for Jenkins

Jenkins must redeploy **backend** so morgan + `[TODO]` logs appear in pods.

### Step 3 — Install Loki (Jenkins EC2, one time)

```bash
cd ~/todo-app && git pull
chmod +x scripts/bootstrap-logging.sh
./scripts/bootstrap-logging.sh
```

Takes ~5–10 minutes. Requires Stage 6 Grafana already running.

### Step 4 — Open Grafana

Same Grafana URL as Stage 6:

```bash
kubectl get svc kube-prometheus-stack-grafana -n monitoring
```

- **Dashboards → Todo App Logs**
- **Explore → Loki** for ad-hoc queries

---

## Todo App Logs dashboard panels

| Panel | What you learn |
|-------|----------------|
| Log lines per minute (all) | Overall activity |
| Backend / frontend volume | Which service is noisier |
| Error lines per minute | Spikes when something breaks |
| HTTP 4xx / 5xx | Failed requests from morgan logs |
| **Live tail — all logs** | Real-time stream (10s refresh) |
| Backend HTTP access (morgan) | Every API call: method, URL, status, ms |
| Backend errors & stack traces | `[ERROR]`, MongoDB, CORS failures |
| Todo operations `[TODO]` | create / update / delete audit trail |
| Frontend nginx logs | Browser requests hitting React/nginx |
| Database / MongoDB | `[DB] MongoDB connected`, driver errors |
| Monitoring namespace errors | Prometheus/Loki/Grafana issues |
| `/api/*` requests | All API traffic across pods |

Link at top jumps to **Todo App Overview** (metrics).

---

## LogQL cheat sheet (Explore → Loki)

```logql
# Everything in your app namespace
{namespace="todo-app"}

# Backend only
{namespace="todo-app", app="backend"}

# Frontend nginx only
{namespace="todo-app", app="frontend"}

# Errors (case insensitive)
{namespace="todo-app"} |~ "(?i)(error|fail|exception)"

# Todo CRUD audit lines
{namespace="todo-app", app="backend"} |~ "\\[TODO\\]"

# HTTP access lines from morgan
{namespace="todo-app", app="backend"} |~ "^(GET|POST|PATCH|DELETE)"

# MongoDB / database
{namespace="todo-app", app="backend"} |~ "(?i)(mongo|mongoose|\\[DB\\])"

# Specific pod
{namespace="todo-app", pod=~"backend-.*"}

# Count errors per minute (metrics from logs)
sum(count_over_time({namespace="todo-app"} |~ "(?i)error"[1m]))
```

---

## Generate log data (try this)

Use the todo app, then watch **Live tail** in Grafana:

1. Open app NLB URL → add a todo → see `[TODO] Created` in Loki
2. Refresh page → see morgan `GET /api/todos 200 ...`
3. Toggle todo complete → `[TODO] Updated`
4. Delete todo → `[TODO] Deleted`

Or from Jenkins EC2:

```bash
NLB=$(kubectl get svc frontend -n todo-app -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
curl -s "http://${NLB}/api/todos"
curl -s -X POST -H "Content-Type: application/json" -d '{"title":"loki test"}' "http://${NLB}/api/todos"
```

Wait ~30 seconds, refresh Grafana dashboard.

---

## Backend log format (after redeploy)

| Tag | Example |
|-----|---------|
| `[STARTUP]` | `Todo API listening on port 5000` |
| `[DB]` | `MongoDB connected successfully` |
| morgan | `GET /api/todos 200 2.345 ms - 128` |
| `[TODO]` | `Created: "buy milk" id=664a...` |
| `[ERROR]` | Error name + message + stack trace |

---

## Troubleshoot

| Problem | Fix |
|---------|-----|
| No logs in Grafana | Check `kubectl get pods -n monitoring -l app.kubernetes.io/name=promtail` |
| Loki pod Pending/OOM | Node low on RAM — reduce retention or use `t3.large` |
| Empty backend panels | Jenkins redeploy backend after git push |
| Datasource missing | Re-apply `kubectl apply -f k8s/logging/datasource-loki.yaml` |
| Dashboard missing | Re-run `./scripts/bootstrap-logging.sh` |

Verify Loki has labels:

```bash
kubectl port-forward -n monitoring svc/loki 3100:3100
curl -sG "http://127.0.0.1:3100/loki/api/v1/labels"
```

Should include `namespace`, `app`, `pod`.

---

## Resource note

Loki + Promtail add ~400–600 MB RAM on your worker node. If pods crash, see Stage 6 resource note (t3.large or shorter retention in `values-loki.yaml`).

---

## Metrics + logs together

1. Open **Todo App Overview** → see 5xx spike in Prometheus
2. Note the time
3. Open **Todo App Logs** → same time range → read exact `[ERROR]` lines

That is full **observability** for learning and interviews.
