# Step 5 — Deploy DevBoard WITHOUT Helm

First deployment path: ArgoCD applies the **raw manifests** in
[`../k8s/`](../k8s/) exactly as they are. No templating, no chart — just plain
YAML kept in sync from Git.

## 5.1 Register the Application

```bash
kubectl apply -f gitops/argocd/devboard-raw.yaml
```

This creates an ArgoCD `Application` called **`devboard-raw`** that watches:

- repo `https://github.com/LondheShubham153/devboard.git`
- branch `gitops`
- path `k8s`
- target namespace `devboard` (auto-created)

Because `syncPolicy.automated` is on, ArgoCD deploys immediately and self-heals
any drift.

## 5.2 Watch it sync

In the UI (http://localhost:8080) you'll see the `devboard-raw` tile go
**Progressing → Healthy / Synced**. Or from the terminal:

```bash
kubectl -n devboard get pods -w
```

Wait for `postgres-statefulset-0`, the backend, and the frontend to be `Running`.

```bash
# Postgres got its EBS disk?
kubectl -n devboard get pvc          # STATUS should be Bound (on gp2)

# Gateway + route created?
kubectl -n devboard get gateway,httproute
```

## 5.3 Get your public URL

The Gateway provisions an AWS NLB — it takes ~2–3 minutes to get an address:

```bash
kubectl -n devboard get gateway devboard-gateway \
  -o jsonpath='{.status.addresses[0].value}' ; echo
```

That prints something like `xxxxxxxx.elb.us-west-2.amazonaws.com`. Test it:

```bash
ADDR=$(kubectl -n devboard get gateway devboard-gateway -o jsonpath='{.status.addresses[0].value}')

curl -s -o /dev/null -w "frontend: HTTP %{http_code}\n" "http://$ADDR/"
curl -s "http://$ADDR/api/projects"     # should return JSON with 2 projects
```

Open `http://$ADDR/` in your browser — DevBoard is live on EKS. 🎉

The `/api/projects` call proves the whole chain works: **NLB → Gateway →
frontend → (internal proxy) → backend → Postgres**.

## 5.4 Try the GitOps magic (optional)

Delete a pod and watch ArgoCD/Kubernetes bring it back:

```bash
kubectl -n devboard delete pod -l app=devboard-frontend
kubectl -n devboard get pods -w
```

Or edit something manually (e.g. scale the frontend to 3) and watch ArgoCD
**self-heal** it back to what Git says.

---

✅ `http://$ADDR/` serves the UI; `/api/projects` returns data.
Next: [`06-package-with-helm.md`](06-package-with-helm.md)
