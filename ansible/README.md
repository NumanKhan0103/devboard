# Set up the EC2 machine with Ansible

Two files. One playbook that installs everything [`../Deploy.md`](../Deploy.md)
needs, and an inventory that says which machine to install it on.

```
ansible/
  inventory.ini    which machine
  playbook.yml     what to install
```

Installs **AWS CLI v2, Terraform, kubectl, Helm, jq, dig, git, gh**. No Docker —
GitHub Actions builds the images and ArgoCD deploys them, so the machine never
needs it.

## What you need

- An Ubuntu EC2 instance (`t3.small` is plenty — nothing runs *on* this box, it
  only talks to the cluster)
- Its public IP and your `.pem` key file
- Ansible on your laptop: `brew install ansible` or `pip install ansible`

## Run it

**1. Edit `inventory.ini`** — put in your IP and key file:

```ini
[devboard]
my-ec2 ansible_host=1.2.3.4 ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/my-key.pem
```

**2. Edit the `vars:` block at the top of `playbook.yml`** — your AWS keys and
your fork's URL:

```yaml
    aws_access_key: "AKIA..."
    aws_secret_key: "wJalr..."
    repo_url: https://github.com/YOUR-USERNAME/devboard.git
```

**3. Run it:**

```bash
cd ansible
ansible-playbook -i inventory.ini playbook.yml
```

It prints every tool's version at the end, so you can see it worked.

**4. Log in and start deploying:**

```bash
ssh ubuntu@1.2.3.4
aws sts get-caller-identity
cd devboard && less Deploy.md
```

## About those AWS keys

Putting keys in a file is the easy way, not the safe way. Two better options
when you are ready:

- **Attach an IAM role to the EC2 instance.** Then leave `aws_access_key` empty —
  the playbook skips the credentials file and the AWS CLI finds the role by
  itself. Nothing to leak, nothing to rotate.
- **Encrypt them** so they are not sitting in a file in plain text:
  ```bash
  ansible-vault encrypt_string 'AKIA...' --name aws_access_key
  ```
  Paste the output into `vars:` and run with `--ask-vault-pass`.

Either way the account needs EKS, VPC, IAM, S3 and Secrets Manager permissions.

## Running it again

Safe to re-run any time — Ansible skips what is already done.

```bash
ansible-playbook -i inventory.ini playbook.yml --check    # dry run, changes nothing
```

## If something breaks

| Problem | Fix |
| --- | --- |
| `UNREACHABLE` / permission denied | `chmod 400 ~/.ssh/my-key.pem`, and check the security group allows SSH from your IP |
| `sudo: a password is required` | Add `--ask-become-pass`, or use the `ubuntu` user which has passwordless sudo |
| Wrong Ubuntu user | Amazon Linux uses `ec2-user`, not `ubuntu` — this playbook expects Ubuntu |
