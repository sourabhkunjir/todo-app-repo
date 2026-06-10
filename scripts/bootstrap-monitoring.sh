#!/bin/bash
# Stage 6 — Install Prometheus + Grafana on EKS (kube-prometheus-stack).
# Run on Jenkins EC2 (or laptop with kubectl + helm + aws cli).

set -euo pipefail

AWS_REGION="${AWS_REGION:-eu-north-1}"
CLUSTER_NAME="${CLUSTER_NAME:-todo-app-prod}"
RELEASE_NAME="${RELEASE_NAME:-kube-prometheus-stack}"
MONITORING_NAMESPACE="${MONITORING_NAMESPACE:-monitoring}"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

echo "==> Configuring kubectl for ${CLUSTER_NAME} (${AWS_REGION})"
aws eks update-kubeconfig --region "${AWS_REGION}" --name "${CLUSTER_NAME}"

echo "==> Adding Helm repo prometheus-community"
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts >/dev/null 2>&1 || true
helm repo update

echo "==> Installing ${RELEASE_NAME} in namespace ${MONITORING_NAMESPACE}"
helm upgrade --install "${RELEASE_NAME}" prometheus-community/kube-prometheus-stack \
  --namespace "${MONITORING_NAMESPACE}" \
  --create-namespace \
  --values "${REPO_ROOT}/k8s/monitoring/values-prometheus-stack.yaml" \
  --wait \
  --timeout 10m

echo "==> Waiting for monitoring pods"
kubectl wait --for=condition=Ready pods \
  -l "app.kubernetes.io/instance=${RELEASE_NAME}" \
  -n "${MONITORING_NAMESPACE}" \
  --timeout=300s

echo "==> Applying Todo App ServiceMonitor and alert rules"
kubectl apply -f "${REPO_ROOT}/k8s/monitoring/servicemonitor-backend.yaml"
kubectl apply -f "${REPO_ROOT}/k8s/monitoring/prometheus-rules-todo-app.yaml"

echo "==> Loading Todo App Grafana dashboard"
kubectl create configmap todo-app-overview \
  -n "${MONITORING_NAMESPACE}" \
  --from-file=todo-app-overview.json="${REPO_ROOT}/k8s/monitoring/dashboards/todo-app-overview.json" \
  --dry-run=client -o yaml | kubectl apply -f -
kubectl label configmap todo-app-overview -n "${MONITORING_NAMESPACE}" grafana_dashboard=1 --overwrite

echo ""
echo "==> Monitoring pods"
kubectl get pods -n "${MONITORING_NAMESPACE}"

GRAFANA_SVC="kube-prometheus-stack-grafana"
echo ""
echo "==> Grafana URL (LoadBalancer may take 2-3 min)"
kubectl get svc "${GRAFANA_SVC}" -n "${MONITORING_NAMESPACE}"

echo ""
echo "==> Grafana credentials"
echo "    User:     admin"
echo "    Password: changeme-grafana-admin   (change after first login)"
echo ""
echo "    Alertmanager UI (port-forward):"
echo "      kubectl port-forward -n ${MONITORING_NAMESPACE} svc/kube-prometheus-stack-alertmanager 9093:9093"
echo ""
echo "    Prometheus UI (port-forward):"
echo "      kubectl port-forward -n ${MONITORING_NAMESPACE} svc/kube-prometheus-stack-prometheus 9090:9090"
echo ""
echo "NOTE: Redeploy backend via Jenkins after prom-client code is merged so /metrics is available."
