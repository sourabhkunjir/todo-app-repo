#!/bin/bash
# Push MONGODB_URI + FRONTEND_URL from AWS Secrets Manager into K8s and restart backend.
# Run on Jenkins EC2 (or anywhere with aws + kubectl).

set -euo pipefail

AWS_REGION="${AWS_REGION:-eu-north-1}"
CLUSTER_NAME="${CLUSTER_NAME:-todo-app-prod}"
SECRETS_MANAGER_NAME="${SECRETS_MANAGER_NAME:-todo-app-prod/app}"
NAMESPACE="${NAMESPACE:-todo-app}"

aws eks update-kubeconfig --region "${AWS_REGION}" --name "${CLUSTER_NAME}" >/dev/null

secret_json="$(aws secretsmanager get-secret-value \
  --secret-id "${SECRETS_MANAGER_NAME}" \
  --region "${AWS_REGION}" \
  --query SecretString --output text)"

mongodb_uri="$(python3 -c "import json,sys; print(json.loads(sys.stdin.read())['MONGODB_URI'])" <<< "${secret_json}")"
frontend_url="$(python3 -c "import json,sys; print(json.loads(sys.stdin.read()).get('FRONTEND_URL',''))" <<< "${secret_json}")"

if [[ -z "${mongodb_uri}" ]]; then
  echo "ERROR: MONGODB_URI is empty in ${SECRETS_MANAGER_NAME}"
  exit 1
fi

if [[ "${mongodb_uri}" == *"?"*"?"* ]]; then
  echo "WARN: MONGODB_URI looks malformed (multiple '?'). Use & between params, e.g. .../todoapp?retryWrites=true&w=majority"
fi

kubectl create secret generic todo-app-secrets -n "${NAMESPACE}" \
  --from-literal=MONGODB_URI="${mongodb_uri}" \
  --from-literal=FRONTEND_URL="${frontend_url}" \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl rollout restart deployment/backend -n "${NAMESPACE}"
kubectl rollout status deployment/backend -n "${NAMESPACE}" --timeout=120s

echo ""
echo "Backend restarted. Test:"
echo "  curl -s http://YOUR-NLB-DNS/api/todos"
echo "  kubectl logs -n ${NAMESPACE} -l app=backend --tail=30"
