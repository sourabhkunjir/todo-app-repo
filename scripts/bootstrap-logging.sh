#!/bin/bash
# Stage 7 — Install Loki + Promtail and wire into existing Grafana.
# Prerequisites: Stage 6 monitoring stack (kube-prometheus-stack) already running.
# Run on Jenkins EC2 (or anywhere with kubectl + helm + aws cli).

set -euo pipefail

AWS_REGION="${AWS_REGION:-eu-north-1}"
CLUSTER_NAME="${CLUSTER_NAME:-todo-app-prod}"
LOGGING_NAMESPACE="${LOGGING_NAMESPACE:-monitoring}"
LOKI_RELEASE="${LOKI_RELEASE:-loki}"
PROMTAIL_RELEASE="${PROMTAIL_RELEASE:-promtail}"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

echo "==> Configuring kubectl for ${CLUSTER_NAME} (${AWS_REGION})"
aws eks update-kubeconfig --region "${AWS_REGION}" --name "${CLUSTER_NAME}"

if ! kubectl get svc kube-prometheus-stack-grafana -n "${LOGGING_NAMESPACE}" >/dev/null 2>&1; then
  echo "ERROR: Grafana not found in namespace ${LOGGING_NAMESPACE}."
  echo "       Run ./scripts/bootstrap-monitoring.sh first (Stage 6)."
  exit 1
fi

echo "==> Adding Grafana Helm repo"
helm repo add grafana https://grafana.github.io/helm-charts >/dev/null 2>&1 || true
helm repo update

echo "==> Installing Loki (${LOKI_RELEASE})"
helm upgrade --install "${LOKI_RELEASE}" grafana/loki \
  --namespace "${LOGGING_NAMESPACE}" \
  --values "${REPO_ROOT}/k8s/logging/values-loki.yaml" \
  --wait \
  --timeout 10m

echo "==> Installing Promtail (${PROMTAIL_RELEASE})"
helm upgrade --install "${PROMTAIL_RELEASE}" grafana/promtail \
  --namespace "${LOGGING_NAMESPACE}" \
  --values "${REPO_ROOT}/k8s/logging/values-promtail.yaml" \
  --wait \
  --timeout 5m

echo "==> Waiting for Loki pod"
kubectl wait --for=condition=Ready pods \
  -l app.kubernetes.io/name=loki \
  -n "${LOGGING_NAMESPACE}" \
  --timeout=300s

echo "==> Applying Loki datasource for Grafana"
kubectl apply -f "${REPO_ROOT}/k8s/logging/datasource-loki.yaml"

echo "==> Loading Todo App Logs dashboard"
kubectl create configmap todo-app-logs \
  -n "${LOGGING_NAMESPACE}" \
  --from-file=todo-app-logs.json="${REPO_ROOT}/k8s/logging/dashboards/todo-app-logs.json" \
  --dry-run=client -o yaml | kubectl apply -f -
kubectl label configmap todo-app-logs -n "${LOGGING_NAMESPACE}" grafana_dashboard=1 --overwrite

echo ""
echo "==> Logging stack pods"
kubectl get pods -n "${LOGGING_NAMESPACE}" -l 'app.kubernetes.io/name in (loki,promtail)'

echo ""
echo "==> Quick LogQL test (may be empty until pods emit logs)"
kubectl port-forward -n "${LOGGING_NAMESPACE}" svc/loki 3100:3100 >/dev/null 2>&1 &
PF_PID=$!
sleep 2
curl -sG "http://127.0.0.1:3100/loki/api/v1/labels" | head -c 200 || true
kill "${PF_PID}" >/dev/null 2>&1 || true

echo ""
echo ""
echo "Done. Open Grafana → Explore → Loki, or Dashboards → Todo App Logs"
echo ""
echo "Example LogQL queries:"
echo '  {namespace="todo-app"}'
echo '  {namespace="todo-app", app="backend"}'
echo '  {namespace="todo-app"} |~ "(?i)(error|fail|exception)"'
echo ""
echo "NOTE: Redeploy backend via Jenkins after morgan logging change for rich HTTP access logs."
