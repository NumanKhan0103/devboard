# The VPC eksctl built for you and never showed you.
#
# `eksctl create cluster` silently provisions all of this: a VPC, nine subnets
# across three AZs, an internet gateway, NAT, route tables, and the two magic
# subnet tags below. That is the single biggest thing this chapter makes
# visible — not that Terraform is better, but that the network was always
# there and you were never asked about it.

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 6.0"

  name = var.cluster_name
  cidr = local.vpc_cidr
  azs  = local.azs

  # Three tiers, each with a job:
  #   public  — the AWS NLB that Envoy Gateway creates. Internet-facing.
  #   private — worker nodes. Reach the internet OUT via NAT; nothing reaches
  #             them IN except through a load balancer.
  #   intra   — no route to the internet at all. The EKS control plane ENIs
  #             live here; they only ever talk to the VPC.
  public_subnets  = local.public_subnets
  private_subnets = local.private_subnets
  intra_subnets   = local.intra_subnets

  enable_nat_gateway = true

  # ONE NAT Gateway for the whole VPC, not one per AZ.
  #
  # Cost: 1 x $0.045/hr = ~$33/month. Three = ~$98/month, and the reference
  # config this is based on quietly does that.
  #
  # The trade-off is real and you should not copy this to production: all
  # egress from all three AZs goes through a single AZ. Lose that AZ and every
  # node loses outbound internet — image pulls included — even though the
  # nodes themselves are fine. Production sets single_nat_gateway = false and
  # one_nat_gateway_per_az = true, and pays the $65 difference for it.
  single_nat_gateway = true

  enable_dns_hostnames = true
  enable_dns_support   = true

  # These two tags are load-bearing magic. AWS load balancer controllers scan
  # subnets for them to decide where to place an ELB. Without the public tag,
  # your Gateway gets no address and nothing tells you why.
  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }

  tags = local.tags
}
