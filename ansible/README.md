# Ansible: the deployment workstation

Provisions an Ubuntu EC2 instance with everything [`../Deploy.md`](../Deploy.md)
section 0.1 asks for, then asserts the versions are right — so a wrong Terraform
fails here in seconds rather than twenty minutes into an apply.

Installs: **AWS CLI v2**, **Terraform**, **kubectl**, **Helm**, **jq**, **dig**,
**git**, **gh**. No Docker — CI builds the images and ArgoCD deploys them, so the
instance never needs it.

## Instance sizing

`t3.small` is enough. Everything here runs *against* the cluster; nothing runs on
the box. Ubuntu 22.04 or 24.04, x86_64 or arm64 (the role detects which).

## Run it

```bash
cd ansible
ansible-galaxy collection install -r requirements.yml

# 1. point the inventory at your instance
$EDITOR inventory/hosts.yml        # ansible_host, ansible_ssh_private_key_file

# 2. add your AWS keys, encrypted
ansible-vault encrypt_string 'AKIA...'   --name devboard_aws_access_key_id
ansible-vault encrypt_string 'wJalr...'  --name devboard_aws_secret_access_key
# paste both blocks into inventory/group_vars/all.yml

# 3. go
ansible-playbook site.yml --ask-vault-pass
```

Then:

```bash
ssh ubuntu@<your-instance>
aws sts get-caller-identity
cd devboard && less Deploy.md          # start at section 0.3
```

## Credentials

The playbook writes `~/.aws/credentials` at mode `0600` with `no_log: true`, but
long-lived keys on a disk are the weaker option. **Attaching an IAM role to the
instance is better** — leave `devboard_aws_access_key_id` empty and the
credentials file is skipped entirely; the AWS CLI picks the role up on its own.
Either way the role needs EKS, VPC, IAM, S3 and Secrets Manager permissions.

## Useful variables

Set these in `inventory/group_vars/all.yml`.

| Variable | Default | Notes |
| --- | --- | --- |
| `devboard_aws_region` | `us-west-2` | Region place #1 of the five in Deploy.md 0.4 |
| `devboard_kubectl_series` | `v1.34` | Keep in step with `kubernetes_version` in `terraform/terraform.tfvars` |
| `devboard_terraform_version` | `""` | Empty means newest; set to pin an apt version |
| `devboard_clone_repo` | `true` | Clones the repo to `~/devboard` |
| `devboard_repo_url` | upstream | **Point this at your fork** |

## Re-running

Idempotent — safe to re-run. Tags let you redo one piece:

```bash
ansible-playbook site.yml --tags verify      # just re-check versions
ansible-playbook site.yml --tags awscli
ansible-playbook site.yml --check --diff     # dry run
```

## Validation

`yamllint`, `ansible-playbook --syntax-check` and `ansible-lint` all pass, the
last at its **production** profile.

```bash
yamllint -d "{extends: relaxed, rules: {line-length: disable}}" .
ansible-playbook site.yml --syntax-check
ansible-lint
```
