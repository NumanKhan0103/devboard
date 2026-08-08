# Version constraints live in their own file so `terraform init -backend=false`
# in CI has one obvious place to look, and so upgrades are a one-file diff.

terraform {
  # 1.11 is the floor, not 1.5.7 as most module docs suggest. Two features
  # below need it:
  #   - S3-native state locking (use_lockfile) in backend.hcl
  #   - write-only arguments (secret_string_wo) in secrets.tf
  required_version = ">= 1.11.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }

    # helm 3.x moved to the Terraform Plugin Framework, which turned the
    # provider's nested BLOCKS into ATTRIBUTES. See providers.tf for what that
    # looks like. If you find a tutorial writing `kubernetes { ... }` with no
    # "=", it is written for v2 and will not parse here.
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.0"
    }

    # Pinned to v2 deliberately. The kubernetes provider ALSO has a v3 that
    # moved to the plugin framework — mixing a v3 helm provider with a v2
    # kubernetes provider in one repo means two nearly identical-looking
    # blocks with different syntax, which is a nasty thing to debug. Keep them
    # explicit; upgrade both together or neither.
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.38"
    }
  }
}
