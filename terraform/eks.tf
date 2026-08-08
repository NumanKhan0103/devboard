module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  # v21 dropped the "cluster_" prefix from about twenty variables to match the
  # AWS API. The renames you will trip over reading a v20 tutorial:
  #   cluster_name      -> name
  #   cluster_version   -> kubernetes_version
  #   cluster_endpoint_* -> endpoint_*
  #   cluster_addons    -> addons
  #   cluster_encryption_config -> encryption_config
  name               = var.cluster_name
  kubernetes_version = var.kubernetes_version

  endpoint_public_access  = true # your laptop reaches the API
  endpoint_private_access = true # nodes reach it over the VPC, not the internet

  # v21 removed the aws-auth ConfigMap entirely: authentication_mode defaults
  # to "API" and identities are mapped with EKS Access Entries instead. This
  # flag makes whoever runs `terraform apply` a cluster admin; without it you
  # build a cluster you cannot log into.
  enable_cluster_creator_admin_permissions = true
  access_entries                           = local.access_entries

  # Only two of the five log types, on purpose. All five is what every
  # compliance scanner wants and costs $5-15/month in CloudWatch ingest on a
  # cluster this size. audit answers "who did what" and authenticator answers
  # "who got in" — the two the security chapter actually uses.
  #
  # checkov:skip=CKV_AWS_37: control plane logging is deliberately partial on a teaching cluster; see the cost note above.
  enabled_log_types                      = ["audit", "authenticator"]
  cloudwatch_log_group_retention_in_days = 7

  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = module.vpc.private_subnets # nodes
  control_plane_subnet_ids = module.vpc.intra_subnets   # control plane ENIs

  addons = {
    coredns    = {}
    kube-proxy = {}

    # before_compute installs these BEFORE the node group exists, so the first
    # node boots with working networking and credentials instead of racing the
    # addon install and flapping NotReady for a few minutes.
    vpc-cni = {
      before_compute = true
    }

    # Required for EKS Pod Identity — the agent DaemonSet is what hands pods
    # their IAM credentials. See pod-identity.tf.
    eks-pod-identity-agent = {
      before_compute = true
    }

    # The frontend HorizontalPodAutoscaler needs this for CPU metrics.
    metrics-server = {}

    # Turns a PersistentVolumeClaim into a real EBS volume. IAM comes from the
    # Pod Identity association in pod-identity.tf, not from an annotation.
    aws-ebs-csi-driver = {}
  }

  eks_managed_node_groups = {
    default = {
      ami_type       = "AL2023_x86_64_STANDARD"
      instance_types = [var.node_instance_type]

      min_size     = var.node_min_size
      max_size     = var.node_max_size
      desired_size = var.node_desired_size

      # `disk_size` is SILENTLY IGNORED here. In v21 the module builds a custom
      # launch template by default, and disk_size only applies when it doesn't
      # — so setting it looks like it works and quietly gives you the AMI
      # default instead. The root volume has to be declared this way.
      block_device_mappings = {
        xvda = {
          device_name = "/dev/xvda"
          ebs = {
            volume_size           = var.node_disk_size
            volume_type           = "gp3"
            encrypted             = true
            delete_on_termination = true
          }
        }
      }

      tags = {
        NodeGroup = "default"
      }
    }
  }

  tags = local.tags
}
