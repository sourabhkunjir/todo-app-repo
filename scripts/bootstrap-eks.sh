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
ESO_ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/todo-app-prod-eso"

echo "==> Configuring kubectl for ${CLUSTER_NAME} (${AWS_REGION})"
aws eks update-kubeconfig --region "${AWS_REGION}" --name "${CLUSTER_NAME}"

echo "==> Installing External Secrets Operator"
helm repo add external-secrets https://charts.external-secrets.io >/dev/null 2>&1 || true
helm repo update

HELM_ARGS=(
  upgrade --install external-secrets external-secrets/external-secrets
  -n external-secrets --create-namespace
  --wait --timeout 5m
  --set "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn=${ESO_ROLE_ARN}"
)

if helm "${HELM_ARGS[@]}" 2>/dev/null; then
  echo "    ESO installed with IRSA role ${ESO_ROLE_ARN}"
else
  echo "    WARN: ESO install with IRSA failed — installing without IRSA (use manual secret fallback)"
  helm upgrade --install external-secrets external-secrets/external-secrets \
    -n external-secrets --create-namespace --wait --timeout 5m
fi

echo "==> Waiting for External Secrets CRDs to be ready..."
for crd in clustersecretstores.external-secrets.io externalsecrets.external-secrets.io; do
  kubectl wait --for=condition=Established "crd/${crd}" --timeout=180s
done

create_secret_from_secrets_manager() {
  echo "==> Creating todo-app-secrets from AWS Secrets Manager"
  local secret_json mongodb_uri frontend_url
  secret_json="$(aws secretsmanager get-secret-value \
    --secret-id "${SECRETS_MANAGER_NAME}" \
    --region "${AWS_REGION}" \
    --query SecretString --output text)"
  mongodb_uri="$(python3 -c "import json,sys; print(json.loads(sys.stdin.read())['MONGODB_URI'])" <<< "${secret_json}")"
  frontend_url="$(python3 -c "import json,sys; print(json.loads(sys.stdin.read()).get('FRONTEND_URL','http://localhost'))" <<< "${secret_json}")"
  kubectl create secret generic todo-app-secrets -n todo-app \
    --from-literal=MONGODB_URI="${mongodb_uri}" \
    --from-literal=FRONTEND_URL="${frontend_url}" \
    --dry-run=client -o yaml | kubectl apply -f -
}

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
kubectl apply -f "${K8S_BUILD}/backend/"
kubectl apply -f "${K8S_BUILD}/frontend/"

if kubectl apply -f "${K8S_BUILD}/external-secrets/" 2>/dev/null; then
  echo "==> Waiting for ExternalSecret to sync (up to 2 min)..."
  kubectl wait --for=condition=Ready externalsecret/todo-app-secrets -n todo-app --timeout=120s 2>/dev/null || \
    create_secret_from_secrets_manager
else
  create_secret_from_secrets_manager
fi

echo ""
echo "==> Pod status"
kubectl get pods -n todo-app

echo ""
echo "==> App URL (NLB — may take 2-3 min to appear)"
kubectl get svc frontend -n todo-app

echo ""
echo "NOTE: Pods show ImagePullBackOff until Jenkins pushes images to ECR (Stage 5/6)."
echo "Run 'terraform apply' on laptop if ESO IRSA role is missing."
