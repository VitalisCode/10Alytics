# EKS Cluster

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.cluster_name
  cluster_version = "1.30" 
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = true

  enable_irsa         = false
  authentication_mode = "API_AND_CONFIG_MAP"

  access_entries = {
    github_actions = {
      kubernetes_groups = []
      principal_arn     = "arn:aws:iam::986232522384:role/github-actions-terraform-role"
      policy_associations = {
        admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
  }

  
  eks_managed_node_groups = {
    example = {
      instance_types = ["t3.small"]
      min_size     = 1
      max_size     = 2
      desired_size = 1
    }
  }
}