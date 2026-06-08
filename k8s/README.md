# Stage 4 — Kubernetes manifests

Deploys the todo app to EKS:

| Resource | Type | Purpose |
|----------|------|---------|
| `backend` | Deployment + ClusterIP | Node API (internal) |
| `frontend` | Deployment + LoadBalancer | nginx + React (public NLB URL) |
| `external-secrets` | ESO | Syncs `MONGODB_URI` from AWS Secrets Manager |

## Prerequisites

- EKS cluster running (`terraform apply` done)
- `kubectl`, `helm`, `aws` CLI configured
- **ESO IRSA role** — run once:

```bash
cd infra/terraform
terraform apply   # creates eso_irsa_role_arn output
```

## Bootstrap (run on Jenkins EC2)

```bash
cd ~/todo-app   # or clone your repo
chmod +x scripts/bootstrap-eks.sh
./scripts/bootstrap-eks.sh
```

Or from laptop (with kubeconfig):

```bash
aws eks update-kubeconfig --region eu-north-1 --name todo-app-prod
./scripts/bootstrap-eks.sh
```

## Get app URL

```bash
kubectl get svc frontend -n todo-app
```

Open `http://<EXTERNAL-IP>/` (AWS NLB DNS name).

## Expected state before Stage 6 (Jenkins pipeline)

Pods may show **ImagePullBackOff** — normal until Docker images are pushed to ECR.

```bash
kubectl get pods -n todo-app
kubectl describe pod -n todo-app -l app=backend
```

## Update CORS after NLB is ready

```bash
NLB_URL="http://YOUR-NLB-DNS.amazonaws.com"
aws secretsmanager put-secret-value \
  --region eu-north-1 \
  --secret-id todo-app-prod/app \
  --secret-string "{\"MONGODB_URI\":\"YOUR_URI\",\"FRONTEND_URL\":\"${NLB_URL}\"}"
```

ExternalSecret refreshes within 1 hour, or restart backend pod:

```bash
kubectl rollout restart deployment/backend -n todo-app
```

## MongoDB Atlas

Allow EKS worker outbound IP in Atlas Network Access (or `0.0.0.0/0` for learning).
