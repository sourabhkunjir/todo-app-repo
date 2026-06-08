#!/bin/bash
# One-time setup on Jenkins EC2 so the jenkins user can run Docker + kubectl in pipelines.
# Run as ubuntu:  sudo bash scripts/prepare-jenkins-pipeline.sh

set -euo pipefail

AWS_REGION="${AWS_REGION:-eu-north-1}"
EKS_CLUSTER="${EKS_CLUSTER:-todo-app-prod}"

echo "==> Adding jenkins user to docker group"
usermod -aG docker jenkins

echo "==> Configuring kubeconfig for jenkins user"
mkdir -p /var/lib/jenkins/.kube
aws eks update-kubeconfig \
  --region "${AWS_REGION}" \
  --name "${EKS_CLUSTER}" \
  --kubeconfig /var/lib/jenkins/.kube/config

chown -R jenkins:jenkins /var/lib/jenkins/.kube

echo "==> Restarting Jenkins to apply docker group"
systemctl restart jenkins

echo ""
echo "Done. Verify as jenkins user:"
echo "  sudo runuser -l jenkins -s /bin/bash -c 'docker ps'"
echo "  sudo runuser -l jenkins -s /bin/bash -c 'kubectl get nodes'"
