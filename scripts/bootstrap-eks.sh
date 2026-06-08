#!/bin/bash
# One-time EKS bootstrap: External Secrets Operator + todo-app manifests.
# Run on Jenkins EC2 (or laptop with kubectl + helm + aws cli).

set -euo pipefail

AWS_REGION="${AWS_REGION:-eu-north-1}"
CLUSTER_NAME="${CLUSTER_NAME:-todo-app-prod}"
SECRETS_MANAGER_NAME="${SECRETS_MANAGER_NAME:-todo-app-prod/app}"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
K8S_BUILD="${REPO_ROOT}/k8s/.rendered"

ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
ECR_BACKEND="${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/todo-app-prod-backend"
ECR_FRONTEND="${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/todo-app-prod-frontend"

echo "==> Configuring kubectl for ${CLUSTER_NAME} (${AWS_REGION})"
aws eks update-kubeconfig --region "${AWS_REGION}" --name "${CLUSTER_NAME}"

ESO_ROLE_ARN=""
if aws iam get-role --role-name "${CLUSTER_NAME}-eso" >/dev/null 2>&1; then
  ESO_ROLE_ARN="$(aws iam get-role --role-name "${CLUSTER_NAME}-eso" --query Role.Arn --output text)"
elif aws iam get-role --role-name "todo-app-prod-eso" >/dev/null 2>&1; then
  ESO_ROLE_ARN="$(aws iam get-role --role-name "todo-app-prod-eso" --query Role.Arn --output text)"
fi

echo "==> Installing External Secrets Operator"
helm repo add external-secrets https://charts.external-secrets.io >/dev/null 2>&1 || true
helm repo update

HELM_ARGS=(
  upgrade --install external-secrets external-secrets/external-secrets
  -n external-secrets --create-namespace
  --wait --timeout 5m
)

if [ -n "${ESO_ROLE_ARN}" ]; then
  echo "    Using IRSA role: ${ESO_ROLE_ARN}"
  HELM_ARGS+=(--set "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn=${ESO_ROLE_ARN}")
else
  echo "    WARN: ESO IRSA role not found — run 'terraform apply' in infra/terraform first"
fi

helm "${HELM_ARGS[@]}"

echo "==> Rendering Kubernetes manifests"
rm -rf "${K8S_BUILD}"
mkdir -p "${K8S_BUILD}/backend" "${K8S_BUILD}/frontend" "${K8S_BUILD}/external-secrets"

render() {
  local src="$1"
  local dst="$2"
  sed \
    -e "s|__ECR_BACKEND_URL__|${ECR_BACKEND}|g" \
    -e "s|__ECR_FRONTEND_URL__|${ECR_FRONTEND}|g" \
    -e "s|__AWS_REGION__|${AWS_REGION}|g" \
    -e "s|__SECRETS_MANAGER_NAME__|${SECRETS_MANAGER_NAME}|g" \
    "${src}" > "${dst}"
}

render "${REPO_ROOT}/k8s/namespace.yaml" "${K8S_BUILD}/namespace.yaml"
render "${REPO_ROOT}/k8s/backend/deployment.yaml" "${K8S_BUILD}/backend/deployment.yaml"
render "${REPO_ROOT}/k8s/backend/service.yaml" "${K8S_BUILD}/backend/service.yaml"
render "${REPO_ROOT}/k8s/frontend/deployment.yaml" "${K8S_BUILD}/frontend/deployment.yaml"
render "${REPO_ROOT}/k8s/frontend/service.yaml" "${K8S_BUILD}/frontend/service.yaml"
render "${REPO_ROOT}/k8s/external-secrets/cluster-secret-store.yaml" "${K8S_BUILD}/external-secrets/cluster-secret-store.yaml"
render "${REPO_ROOT}/k8s/external-secrets/external-secret.yaml" "${K8S_BUILD}/external-secrets/external-secret.yaml"

echo "==> Applying manifests"
kubectl apply -f "${K8S_BUILD}/namespace.yaml"
kubectl apply -f "${K8S_BUILD}/external-secrets/"
kubectl apply -f "${K8S_BUILD}/backend/"
kubectl apply -f "${K8S_BUILD}/frontend/"

echo ""
echo "==> Waiting for ExternalSecret to sync (up to 2 min)..."
kubectl wait --for=condition=Ready externalsecret/todo-app-secrets -n todo-app --timeout=120s 2>/dev/null || true

echo ""
echo "==> Pod status"
kubectl get pods -n todo-app

echo ""
echo "==> App URL (NLB — may take 2-3 min to appear)"
kubectl get svc frontend -n todo-app

echo ""
echo "NOTE: Pods stay ImagePullBackOff until Jenkins pushes images to ECR (Stage 6)."
echo "After NLB hostname appears, update FRONTEND_URL in Secrets Manager for CORS."
