# Step 1 — Prerequisites

## Tools

| Tool | Purpose |
|------|---------|
| `awscli` | talk to AWS |
| `eksctl` | create/delete the cluster |
| `kubectl` | talk to the cluster |
| `helm` | install ArgoCD & render the chart |

macOS:
```bash
brew install awscli eksctl kubernetes-cli helm
```

Linux (eksctl):
```bash
curl -sLO "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz"
tar -xzf eksctl_*.tar.gz && sudo mv eksctl /usr/local/bin
```

## Configure AWS

You need an IAM user/role that can create EKS (EKS + CloudFormation + EC2 + IAM;
`AdministratorAccess` is simplest for learning).

```bash
aws configure          # region: us-west-2
aws sts get-caller-identity   # must succeed
```

All docs use **us-west-2**. To change it, edit both `aws configure` and
`gitops/eksctl/cluster.yaml`.

Next: [02-create-eks.md](02-create-eks.md)
