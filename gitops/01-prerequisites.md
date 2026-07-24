# Step 1 — Prerequisites

Before we touch AWS, let's get the tools on your machine and make sure your AWS
account is reachable.

## 1.1 Tools you need

| Tool | What it's for | Check |
| --- | --- | --- |
| `awscli` | talk to AWS | `aws --version` |
| `eksctl` | create/delete the EKS cluster | `eksctl version` |
| `kubectl` | talk to the cluster | `kubectl version --client` |
| `helm` | install ArgoCD & render our chart | `helm version` |
| `argocd` (optional) | ArgoCD from the terminal | `argocd version --client` |

### Install on macOS (Homebrew)

```bash
brew install awscli eksctl kubernetes-cli helm
brew install argocd            # optional — the UI works fine without it
```

### Install on Linux

```bash
# eksctl
curl -sLO "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz"
tar -xzf eksctl_*.tar.gz && sudo mv eksctl /usr/local/bin

# kubectl, helm, awscli — follow their official docs, or use your package manager.
```

## 1.2 Configure AWS

You need an IAM user/role with permission to create EKS clusters (Administrator
access is easiest for learning).

```bash
aws configure          # enter Access Key, Secret Key, region = us-west-2, output = json
```

Verify it works — this must print your account and identity:

```bash
aws sts get-caller-identity
```

> If you see your account number, you're good. If you get an error, fix your
> credentials before continuing — everything downstream depends on this.

## 1.3 A quick note on region

Every command in these docs uses **`us-west-2`** (Oregon), matching
`eksctl/cluster.yaml`. If you want a different region, change it in **both**
places: `aws configure` and `gitops/eksctl/cluster.yaml`.

---

✅ Tools installed, `aws sts get-caller-identity` works.
Next: [`02-create-eks.md`](02-create-eks.md)
