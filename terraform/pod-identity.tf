# How a pod gets AWS permissions, without a single access key.
#
# There are two mechanisms and it matters which one you are reading about:
#
#   IRSA (older) — the ServiceAccount carries an eks.amazonaws.com/role-arn
#     annotation; the IAM trust policy references the cluster's OIDC provider
#     URL. Cluster-specific, so destroy + recreate invalidates every role.
#
#   Pod Identity (used here) — an ASSOCIATION object maps a namespace +
#     ServiceAccount to a role. The trust policy just names the static
#     pods.eks.amazonaws.com principal, so it survives cluster rebuilds, and
#     the ServiceAccount needs no annotation at all.
#
# Both need something running: IRSA needs the OIDC provider, Pod Identity
# needs the eks-pod-identity-agent addon (see eks.tf).
#
# Note the associations below reference namespaces and ServiceAccounts that do
# not exist yet. AWS does not validate them, which is exactly what lets
# Terraform own the IAM while ArgoCD owns the workload.

# EBS CSI controller — replaces eksctl's wellKnownPolicies.ebsCSIController.
# Without this, every PersistentVolumeClaim in the cluster stays Pending.
module "ebs_csi_pod_identity" {
  source  = "terraform-aws-modules/eks-pod-identity/aws"
  version = "~> 2.0"

  name                      = "${var.cluster_name}-ebs-csi"
  attach_aws_ebs_csi_policy = true

  associations = {
    this = {
      cluster_name    = module.eks.cluster_name
      namespace       = "kube-system"
      service_account = "ebs-csi-controller-sa"
    }
  }

  tags = local.tags
}

# External Secrets Operator — read-only, and scoped to exactly our secrets.
#
# The scoping is the point. ESO with secretsmanager:GetSecretValue on "*" can
# read every secret in the account; one compromised operator then owns your
# production database credentials. The ARN pattern below limits it to
# devboard/* and nothing else.
module "external_secrets_pod_identity" {
  source  = "terraform-aws-modules/eks-pod-identity/aws"
  version = "~> 2.0"

  name                           = "${var.cluster_name}-external-secrets"
  attach_external_secrets_policy = true

  # ESO reads secrets. It never creates or updates them — that is a human's
  # job (see secrets.tf and gitops/06-secrets-with-secrets-manager.md).
  external_secrets_create_permission = false

  # We use Secrets Manager only, not SSM Parameter Store. An empty list here
  # means no SSM permissions are attached at all.
  external_secrets_ssm_parameter_arns = []

  external_secrets_secrets_manager_arns = [
    "arn:aws:secretsmanager:${var.region}:${local.account_id}:secret:devboard/*",
  ]

  associations = {
    this = {
      cluster_name = module.eks.cluster_name
      namespace    = "external-secrets"
      # Must match the ServiceAccount name the ESO Helm chart creates — see
      # gitops/argocd/platform/external-secrets.yaml.
      service_account = "external-secrets"
    }
  }

  tags = local.tags
}
