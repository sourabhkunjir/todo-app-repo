module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.24"

  cluster_name    = local.name
  cluster_version = var.eks_cluster_version

  vpc_id     = aws_vpc.main.id
  subnet_ids = aws_subnet.public[*].id

  cluster_endpoint_public_access = true

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
