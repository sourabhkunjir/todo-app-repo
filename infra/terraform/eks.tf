module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.24"

  cluster_name    = local.name
  cluster_version = var.eks_cluster_version

  vpc_id     = aws_vpc.main.id
  subnet_ids = aws_subnet.public[*].id

  cluster_endpoint_public_access                   = true
  cluster_endpoint_public_access_cidrs             = ["0.0.0.0/0"]
  cluster_endpoint_private_access                  = true

  # Jenkins EC2 reaches EKS API via private VPC IPs — allow port 443
  cluster_security_group_additional_rules = {
    ingress_jenkins_https = {
      description              = "Jenkins EC2 to EKS API"
      protocol                 = "tcp"
      from_port                = 443
      to_port                  = 443
      type                     = "ingress"
      source_security_group_id = aws_security_group.jenkins.id
    }
  }

  eks_managed_node_groups = {
    main = {
      min_size     = var.eks_node_min_size
      max_size     = var.eks_node_max_size
      desired_size = var.eks_node_desired_size

      instance_types = [var.eks_node_instance_type]
      capacity_type  = "ON_DEMAND"
      ami_type       = "AL2023_x86_64_STANDARD"

      iam_role_additional_policies = {
        ECRReadOnly = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
      }
    }
  }

  enable_cluster_creator_admin_permissions = true

  access_entries = {
    jenkins = {
      principal_arn = aws_iam_role.jenkins.arn

      policy_associations = {
        cluster_admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
  }
}
