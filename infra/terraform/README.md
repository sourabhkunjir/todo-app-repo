# Stage 3 — Terraform (AWS infrastructure)

Creates: VPC, EKS (1 worker), ECR (2 repos), Jenkins EC2 + Elastic IP, Secrets Manager, S3 state bucket.

## Before you run

1. AWS CLI configured: `aws sts get-caller-identity`
2. [Terraform installed](https://developer.hashicorp.com/terraform/install) (>= 1.5)
3. **EC2 key pair** created in AWS Console (same region) — save the `.pem` file
4. Your public IP: visit https://ifconfig.me → use as `YOUR_IP/32` in tfvars
5. MongoDB Atlas `MONGODB_URI` ready

## Steps

```bash
cd infra/terraform

# 1. Copy and edit variables (includes mongodb_uri secret)
cp terraform.tfvars.example terraform.tfvars

# 2. Initialize (downloads EKS module)
terraform init

# 3. Preview (~10–15 min apply time for EKS)
terraform plan

# 4. Create everything
terraform apply
```

Type `yes` when prompted. EKS alone takes ~10 minutes.

## After apply — save these outputs

```bash
terraform output jenkins_elastic_ip
terraform output jenkins_url
terraform output ecr_backend_url
terraform output ecr_frontend_url
terraform output eks_cluster_name
terraform output configure_kubectl_command
```

## Jenkins first login

1. Wait **5–8 min** after apply (bootstrap installs Jenkins first, then Docker/AWS CLI)
2. SSH: `ssh -i your-key.pem ubuntu@<jenkins_elastic_ip>`
3. Verify bootstrap: `sudo cat /var/log/jenkins-bootstrap.log`
4. Get password: `sudo cat /var/lib/jenkins/secrets/initialAdminPassword`
5. Open `http://<jenkins_elastic_ip>:8080` in browser

### No public IP in AWS Console / EC2 Instance Connect fails

**Do not use EC2 Instance Connect** for this setup — use **SSH with your `.pem` key** instead.

Jenkins uses a **separate Elastic IP** (static). After instance replace, the EIP can briefly show as **unassociated** until you run `terraform apply`.

1. **EC2 → Elastic IP addresses** → find `todo-app-prod-jenkins-eip` → must show **Associated instance**
2. Use that IP for SSH/Jenkins (not the instance’s temporary auto-assigned IP):

```bash
terraform output jenkins_elastic_ip
terraform output jenkins_ssh_command
```

3. Fix association if missing:

```bash
terraform apply
```

If still broken, force re-attach:

```bash
terraform apply -replace="aws_eip.jenkins" -replace="aws_instance.jenkins"
```

Wait 2 min — Elastic IP `51.20.x.x` should appear on the instance under **Public IPv4 address**.

### If Jenkins is missing after apply

The startup script only runs **once** when EC2 is created. If an old broken script ran, recreate the instance:

```bash
terraform apply -replace="aws_instance.jenkins"
```

Elastic IP stays the same. Wait 5–8 min, then check logs on the new instance:

```bash
sudo tail -30 /var/log/jenkins-bootstrap.log
sudo systemctl status jenkins
```

**What was fixed in the bootstrap script:**
- Jenkins installs **first** (before Docker/AWS CLI)
- Optional tools cannot fail the whole script
- No `templatefile()` (avoids `${VAR}` conflicts with bash)
- `user_data_replace_on_change = true` — script updates recreate EC2 on `terraform apply`

## MongoDB Atlas

After apply, in Atlas → Network Access, allow **`0.0.0.0/0`** (learning) or the EKS worker public IP.

## Update CORS URL later

After Stage 4 (K8s deploy), get NLB DNS from `kubectl get svc frontend -n todo-app`, then update secret:

```bash
aws secretsmanager put-secret-value \
  --secret-id todo-app-prod/app \
  --secret-string '{"MONGODB_URI":"...","FRONTEND_URL":"http://YOUR-NLB-DNS"}'
```

## Destroy (stop billing)

```bash
terraform destroy
```

Empty ECR repos first if destroy fails on repositories with images.

## Server summary

| Resource | Type | Purpose |
|----------|------|---------|
| Jenkins EC2 | t3.small + Elastic IP | CI/CD |
| EKS worker | t3.medium × 1 | Runs app pods |
| EKS control plane | AWS managed | Kubernetes API |
