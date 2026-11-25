module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 6.0"

  name = "${var.cluster_name}-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["${var.region}a", "${var.region}b"]
  private_subnets = ["10.0.0.0/20", "10.0.16.0/20"]  # nodes + pods
  public_subnets  = ["10.0.96.0/24", "10.0.97.0/24"] # load balancers + NAT

  enable_nat_gateway = true
  single_nat_gateway = false # one NAT = cheaper (not HA, fine for demos)

  # Tags so EKS knows where to put load balancers
  public_subnet_tags  = { "kubernetes.io/role/elb" = 1 }
  private_subnet_tags = { "kubernetes.io/role/internal-elb" = 1 }
}
