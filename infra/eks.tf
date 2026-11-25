module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  name = var.cluster_name
  # kubernetes_version not pinned: AWS uses its current default version

  endpoint_public_access = true

  # Same KMS admins no matter who runs Terraform (laptop or GitHub Actions)
  kms_key_administrators = var.admin_arns

  # EKS Auto Mode: AWS manages nodes, scaling, load balancers, storage
  compute_config = {
    enabled    = true
    node_pools = ["general-purpose", "system"]
  }

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  enable_cluster_creator_admin_permissions = false
  access_entries = {
    for i, arn in var.admin_arns : "admin-${i}" => {
      principal_arn = arn
      policy_associations = {
        admin = {
          policy_arn   = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = { type = "cluster" }
        }
      }
    }
  }
}
