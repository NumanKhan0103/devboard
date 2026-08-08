# Terraform creates the secret's NAME. It does not create the VALUE, and that
# is the entire point of this file.
#
# terraform.tfstate is a plaintext JSON document. Every argument you pass to
# every resource is written into it verbatim. `sensitive = true` hides a value
# from CLI output — it does nothing to the file. Our state lives in S3,
# encrypted and versioned and private, but "encrypted at rest in a bucket
# several people can read" is not the same claim as "nobody has the password".
#
# So the split is:
#   container = infrastructure  -> code, here
#   value     = a credential    -> set out of band, once
#
# See gitops/06-secrets-with-secrets-manager.md, which has you run
# `terraform state pull | jq` afterwards to confirm the password really is
# not in there.

resource "aws_secretsmanager_secret" "postgres" {
  name        = var.postgres_secret_name
  description = "DevBoard in-cluster Postgres credentials. Value set out of band; see gitops/06-secrets-with-secrets-manager.md."

  # 0 = delete immediately on destroy.
  #
  # The default is a 30-day recovery window, which sounds prudent until you
  # `terraform destroy` a teaching cluster and then cannot recreate it, because
  # every apply for the next MONTH fails with "You can't create this secret
  # because a secret with this name is already scheduled for deletion."
  # In production you want the default. Here you want to be able to rebuild.
  recovery_window_in_days = 0

  tags = local.tags
}

# ---------------------------------------------------------------------------
# ADVANCED — setting the value from Terraform without leaking it into state.
#
# The lesson is "never put secrets in state", not "never automate secrets".
# Terraform 1.11 + AWS provider 6.x added WRITE-ONLY arguments for exactly
# this: the value is sent to the API and then discarded, never persisted to
# state or to a plan file.
#
# Uncomment, then:  terraform apply -var="postgres_password=$(openssl rand -hex 32)"
#
# variable "postgres_password" {
#   type      = string
#   sensitive = true
#   ephemeral = true   # cannot be written to state or a plan file, ever
#   default   = null
# }
#
# resource "aws_secretsmanager_secret_version" "postgres" {
#   count     = var.postgres_password == null ? 0 : 1
#   secret_id = aws_secretsmanager_secret.postgres.id
#
#   secret_string_wo = jsonencode({
#     username = "devboard"
#     password = var.postgres_password
#     dbname   = "devboard"
#   })
#
#   # Bump this integer by hand to make Terraform re-send the value.
#   #
#   # It cannot itself be ephemeral, and the reason is worth sitting with:
#   # Terraform diffs by comparing state to config, but it is not allowed to
#   # remember a write-only value — so it has nothing to compare. The version
#   # counter IS the diff. You are telling Terraform "this changed", because
#   # it has no way to find out on its own.
#   secret_string_wo_version = 1
# }
# ---------------------------------------------------------------------------
