#!/bin/bash
# EC2 first-boot bootstrap: Jenkins (required) then Docker/AWS CLI/kubectl (optional).
# Placeholders __AWS_REGION__ and __CLUSTER_NAME__ are replaced by Terraform.
# Jenkins install follows official docs: https://www.jenkins.io/doc/book/installing/linux/

LOG="/var/log/jenkins-user-data.log"
BOOT="/var/log/jenkins-bootstrap.log"

exec > >(tee -a "$LOG") 2>&1
echo "=== Bootstrap started: $(date -Iseconds) ===" | tee -a "$BOOT"

export DEBIAN_FRONTEND=noninteractive

AWS_REGION="__AWS_REGION__"
CLUSTER_NAME="__CLUSTER_NAME__"

log() {
  echo "[$(date -Iseconds)] $*" | tee -a "$BOOT"
}

die() {
  log "FATAL: $*"
  exit 1
}

install_jenkins() {
  log "Installing Jenkins (official 2026 apt method)..."

  apt-get update -y || die "apt-get update failed"
  apt-get install -y ca-certificates curl gnupg wget fontconfig openjdk-21-jre \
    || die "failed to install base packages (Java 21 required by Jenkins)"

  install -m 0755 -d /etc/apt/keyrings
  wget -q -O /etc/apt/keyrings/jenkins-keyring.asc \
    https://pkg.jenkins.io/debian-stable/jenkins.io-2026.key \
    || die "failed to download Jenkins GPG key (jenkins.io-2026.key)"

  echo "deb [signed-by=/etc/apt/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/" \
    > /etc/apt/sources.list.d/jenkins.list

  apt-get update -y 2>&1 | tee -a "$BOOT" || die "apt-get update (jenkins repo) failed"

  apt-get install -y jenkins 2>&1 | tee -a "$BOOT" || die "apt-get install jenkins failed"

  if ! dpkg -l jenkins 2>/dev/null | grep -q '^ii'; then
    die "jenkins package not installed"
  fi

  # Listen on all interfaces (Elastic IP :8080)
  if grep -q '^JENKINS_LISTEN_ADDRESS=' /etc/default/jenkins 2>/dev/null; then
    sed -i 's/^JENKINS_LISTEN_ADDRESS=.*/JENKINS_LISTEN_ADDRESS=0.0.0.0/' /etc/default/jenkins
  else
    echo 'JENKINS_LISTEN_ADDRESS=0.0.0.0' >> /etc/default/jenkins
  fi

  systemctl daemon-reload
  systemctl enable jenkins
  systemctl start jenkins

  for attempt in 1 2 3 4 5 6 7 8 9 10; do
    if systemctl is-active --quiet jenkins; then
      log "Jenkins is running on port 8080 (attempt ${attempt})"
      return 0
    fi
    sleep 3
  done

  journalctl -u jenkins --no-pager -n 30 | tee -a "$BOOT" || true
  die "jenkins service did not become active"
}

install_optional_tools() {
  log "Installing optional tools..."
  set +e

  curl -fsSL https://get.docker.com | sh
  usermod -aG docker ubuntu 2>/dev/null
  usermod -aG docker jenkins 2>/dev/null

  curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip
  unzip -q -o /tmp/awscliv2.zip -d /tmp
  /tmp/aws/install
  rm -rf /tmp/aws /tmp/awscliv2.zip

  KUBECTL_VERSION="$(curl -fsSL https://dl.k8s.io/release/stable.txt)"
  curl -fsSL "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl" \
    -o /usr/local/bin/kubectl
  chmod +x /usr/local/bin/kubectl

  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

  set -e
  log "Optional tools finished"
}

configure_kubeconfig() {
  log "Configuring kubeconfig..."
  set +e

  if ! command -v aws >/dev/null 2>&1; then
    log "WARN: aws CLI missing — skip kubeconfig"
    return 0
  fi

  runuser -l ubuntu -c "aws eks update-kubeconfig --region ${AWS_REGION} --name ${CLUSTER_NAME}"
  mkdir -p /var/lib/jenkins/.kube
  runuser -l jenkins -c "aws eks update-kubeconfig --region ${AWS_REGION} --name ${CLUSTER_NAME} --kubeconfig /var/lib/jenkins/.kube/config"
  chown -R jenkins:jenkins /var/lib/jenkins/.kube

  set -e
}

install_jenkins
install_optional_tools
configure_kubeconfig

log "Bootstrap complete: $(date -Iseconds)"
echo "=== Bootstrap finished OK ===" | tee -a "$BOOT"
