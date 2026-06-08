resource "aws_security_group" "jenkins" {
  name        = "${local.name}-jenkins-sg"
  description = "Jenkins controller on EC2"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "Jenkins UI and GitHub webhooks"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH from your IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ssh_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.name}-jenkins-sg"
  }
}

resource "aws_instance" "jenkins" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.jenkins_instance_type
  subnet_id                   = aws_subnet.public[0].id
  vpc_security_group_ids      = [aws_security_group.jenkins.id]
  iam_instance_profile        = aws_iam_instance_profile.jenkins.name
  key_name                    = var.ssh_key_name
  associate_public_ip_address = true

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
  }

  user_data = replace(
    replace(
      file("${path.module}/scripts/jenkins-user-data.sh"),
      "__AWS_REGION__",
      var.aws_region
    ),
    "__CLUSTER_NAME__",
    local.name
  )
  user_data_replace_on_change = true

  depends_on = [module.eks]

  tags = {
    Name = "${local.name}-jenkins"
  }
}

# Elastic IP tied directly to the instance — re-attaches automatically when instance is replaced.
resource "aws_eip" "jenkins" {
  domain   = "vpc"
  instance = aws_instance.jenkins.id

  tags = {
    Name = "${local.name}-jenkins-eip"
  }

  depends_on = [aws_internet_gateway.main]
}
