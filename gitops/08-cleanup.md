# Step 8 — Clean up

EKS, NLBs, and EBS cost money. Delete the apps first (that removes the Gateways,
which frees the NLBs), then the cluster.

```bash
# 1. delete the apps — prune:true removes the Gateways/NLBs
kubectl delete -f gitops/argocd/devboard-raw.yaml
kubectl delete -f gitops/argocd/devboard-helm.yaml
kubectl delete -f gitops/argocd/ollama.yaml
kubectl get gateway -A            # should be empty

# 2. (optional) remove the platform pieces
helm uninstall argocd -n argocd
helm uninstall eg -n envoy-gateway-system

# 3. delete the cluster (~10-15 min)
eksctl delete cluster -f gitops/eksctl/cluster.yaml
```

Verify nothing's left billing you:
```bash
eksctl get cluster --region us-west-2      # devboard gone
```
Also check the AWS console for stray Load Balancers / EBS volumes in `us-west-2`.
