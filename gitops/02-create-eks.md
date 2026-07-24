# Step 2 — Create the EKS cluster

We describe the whole cluster in one file — [`eksctl/cluster.yaml`](eksctl/cluster.yaml) —
and let eksctl build it. No console clicking, no Terraform.

## 2.1 What's in the cluster file (plain English)

- **Name** `devboard`, **region** `us-west-2`.
- **OIDC enabled** — required so add-ons can get their own IAM permissions.
- **2 × t3.medium** worker nodes (can scale to 3).
- **Add-ons**: `vpc-cni`, `coredns`, `kube-proxy`, and **`aws-ebs-csi-driver`**.
  That last one is important: it lets our Postgres StatefulSet request a real
  **EBS disk** on the fly through the default `gp2` StorageClass.

## 2.2 Create it

```bash
eksctl create cluster -f gitops/eksctl/cluster.yaml
```

⏳ This takes **~15–20 minutes** (it builds a VPC, the control plane, nodes, and
IAM roles). Grab a coffee. When it finishes, eksctl automatically points your
`kubectl` at the new cluster.

## 2.3 Verify

```bash
# Two nodes, both Ready
kubectl get nodes

# The gp2 StorageClass exists (this is what Postgres will use)
kubectl get storageclass

# The EBS CSI driver is running
kubectl -n kube-system get pods | grep ebs-csi
```

You should see 2 `Ready` nodes, a `gp2 (default)` StorageClass, and a few
`ebs-csi-*` pods `Running`.

> **Why we care about EBS here:** Postgres runs as a StatefulSet with a
> PersistentVolumeClaim. Without the EBS CSI driver, that claim would sit
> `Pending` forever (we actually saw this failure mode on a local cluster).
> On EKS the driver provisions the disk automatically.

---

✅ `kubectl get nodes` shows 2 Ready nodes; `gp2` StorageClass present.
Next: [`03-gateway-api.md`](03-gateway-api.md)
