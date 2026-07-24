# Step 8 — Clean up (stop paying!)

EKS, NLBs, and EBS volumes all cost money. When you're done learning, tear it all
down. **Order matters** — delete the app-created load balancers *before* the
cluster, so nothing gets orphaned in your AWS account.

## 8.1 Remove the apps (this deletes the NLBs)

Because our ArgoCD apps have `prune: true`, deleting the `Application` deletes
everything it created — including the Gateways, which makes Envoy remove the
AWS NLBs.

```bash
kubectl delete -f gitops/argocd/devboard-raw.yaml
kubectl delete -f gitops/argocd/devboard-helm.yaml

# confirm the Gateways (and their NLBs) are gone
kubectl get gateway -A
```

Give it a minute, then double-check in the AWS console (EC2 → Load Balancers)
that no `devboard` NLB remains.

## 8.2 (Optional) uninstall the platform pieces

If you're keeping the cluster but want a clean slate:

```bash
helm uninstall argocd -n argocd
helm uninstall eg -n envoy-gateway-system
```

## 8.3 Delete the whole cluster

The simplest way to guarantee you stop paying — delete the cluster. eksctl tears
down the nodes, control plane, VPC, and IAM roles it created:

```bash
eksctl delete cluster -f gitops/eksctl/cluster.yaml
```

⏳ Takes ~10–15 minutes.

## 8.4 Final check

```bash
eksctl get cluster --region us-west-2      # should NOT list "devboard"
```

Also glance at the AWS console for leftover **Load Balancers** and **EBS
volumes** in `us-west-2` — if you deleted the Gateways first (8.1), there should
be none.

---

🎉 That's the whole journey: eksctl → Gateway API → ArgoCD → app, deployed both
with and without Helm. Nice work!
