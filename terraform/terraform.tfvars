# Committed on purpose — these are teaching defaults, not secrets. Terraform
# loads this file automatically.
#
# Anything genuinely sensitive belongs in AWS Secrets Manager (see secrets.tf),
# never here and never in state.

region             = "us-west-2"
cluster_name       = "devboard"
kubernetes_version = "1.34"

node_instance_type = "t3.large"
node_desired_size  = 3
node_min_size      = 2
node_max_size      = 4
