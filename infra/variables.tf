variable "region" {
  type    = string
  default = "ap-south-1"
}

variable "cluster_name" {
  type    = string
  default = "gitops-eks"
}

# Always APPEND to this list, never reorder (keys are index-based)
variable "admin_arns" {
  description = "IAM users/roles that get cluster-admin on EKS"
  type        = list(string)
  default = [
    "arn:aws:iam::287629436195:user/namanadmin",
    "arn:aws:iam::287629436195:role/github-actions-eks-terraform",
  ]
}
