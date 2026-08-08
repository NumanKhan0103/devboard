provider "aws" {
  region = var.region

  default_tags {
    tags = local.tags
  }
}

# helm 3.x uses ATTRIBUTE syntax (note every "="). In helm 2.x these were
# nested blocks with no "=". If you hit "Blocks of type kubernetes are not
# expected here", you are reading a v2-era tutorial.
#
# The exec block means Terraform shells out to `aws eks get-token` for a fresh
# credential on every run, rather than baking a 15-minute token into state.
provider "helm" {
  kubernetes = {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

    exec = {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name, "--region", var.region]
    }
  }
}

# kubernetes 2.x still uses BLOCK syntax. Same idea, different shape — see the
# note in versions.tf about why the two providers are pinned to different
# major versions on purpose.
provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name, "--region", var.region]
  }
}

data "aws_caller_identity" "current" {}

# opt-in-not-required filters out AZs like ap-east-1 that need an explicit
# account opt-in — asking for a subnet in one of those fails at apply time.
data "aws_availability_zones" "available" {
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

locals {
  account_id = data.aws_caller_identity.current.account_id

  # Three AZs. EKS requires at least two; three means the control plane and a
  # rolling node replacement always have somewhere to go.
  azs = slice(data.aws_availability_zones.available.names, 0, 3)

  vpc_cidr = "10.0.0.0/16"

  # /24 each = 251 usable IPs per subnet. With the VPC CNI handing every pod a
  # real VPC IP, subnet sizing is a real constraint — this is one of the things
  # eksctl decided for you without asking.
  public_subnets  = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  private_subnets = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
  intra_subnets   = ["10.0.7.0/24", "10.0.8.0/24", "10.0.9.0/24"]

  tags = {
    Project   = "devboard"
    ManagedBy = "terraform"
    Cluster   = var.cluster_name
  }

  # An access entry maps an IAM principal to Kubernetes groups. This is what
  # replaced the aws-auth ConfigMap in EKS module v21 (authentication_mode
  # defaults to "API" and the aws-auth submodule was deleted outright).
  #
  # k8s/intern-role-binding.yml binds the "devboard-interns" GROUP, so an IAM
  # role listed here lands straight in that Role. IAM identity -> EKS access
  # entry -> Kubernetes group -> RBAC Role, end to end.
  access_entries = var.intern_iam_principal_arn == null ? {} : {
    intern = {
      principal_arn     = var.intern_iam_principal_arn
      type              = "STANDARD"
      kubernetes_groups = ["devboard-interns"]
    }
  }
}
