# Step 4 — Install ArgoCD

ArgoCD is our **GitOps engine**. You point it at a Git repo + path, and it makes
the cluster match what's in Git — and keeps it that way.

## 4.1 Install with Helm

```bash
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

helm install argocd argo/argo-cd \
  --namespace argocd --create-namespace \
  -f gitops/argocd/install-values.yaml

# wait for the API server to be ready
kubectl -n argocd rollout status deploy/argocd-server
```

> Our [`install-values.yaml`](argocd/install-values.yaml) sets
> `server.insecure: true` so the UI serves plain HTTP — that keeps the
> port-forward below simple. Fine for learning; add TLS for anything real.

## 4.2 Get the admin password

ArgoCD generates a random `admin` password on first install:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d ; echo
```

Copy that value.

## 4.3 Open the UI

```bash
kubectl -n argocd port-forward svc/argocd-server 8080:80
```

Now open **http://localhost:8080** and log in:

- **Username:** `admin`
- **Password:** the value from 4.2

(Optional) log in with the CLI too:

```bash
argocd login localhost:8080 --username admin --password '<paste>' --insecure
```

## 4.4 What happens next

We won't create apps in the UI — that wouldn't be GitOps. Instead we `kubectl
apply` two small **Application** manifests (they live in
[`argocd/`](argocd/)). Each tells ArgoCD which repo, branch, and path to watch.
From then on, ArgoCD does the deploying.

---

✅ ArgoCD UI reachable at http://localhost:8080, logged in as `admin`.
Next: [`05-deploy-without-helm.md`](05-deploy-without-helm.md)
