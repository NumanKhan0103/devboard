terraform {
  # PARTIAL backend configuration, on purpose.
  #
  # S3 bucket names are globally unique, so yours is personal to you and cannot
  # be committed to a repo other people fork. Terraform lets you leave the
  # block empty and supply the rest at init time:
  #
  #   cd terraform/bootstrap && terraform init && terraform apply
  #   terraform output -raw backend_hcl > ../backend.hcl
  #   cd .. && terraform init -backend-config=backend.hcl
  #
  # backend.hcl is gitignored. backend.hcl.example shows its shape.
  backend "s3" {}
}
