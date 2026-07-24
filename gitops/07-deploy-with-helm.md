# Step 7 — Deploy DevBoard WITH Helm (via ArgoCD)

Now we let ArgoCD deploy the **chart**. ArgoCD renders `helm/devboard` itself and
syncs the result into a **separate namespace** (`devboard-helm`) so it runs
side-by-side with the raw version from Step 5.

## 7.1 Register the Application

```bash
kubectl apply -f gitops/argocd/devboard-helm.yaml
```

This creates the ArgoCD `Application` **`devboard-helm`**, watching:

- repo `https://github.com/LondheShubham153/devboard.git`, branch `gitops`
- path `helm/devboard`  ← a Helm chart, not raw YAML
- target namespace `devboard-helm`

ArgoCD detects it's a Helm chart, runs the equivalent of `helm template`, and
applies the output. To change a value, edit
[`devboard-helm.yaml`](argocd/devboard-helm.yaml)'s `helm.valuesObject` (or the
chart's `values.yaml`) and commit — ArgoCD picks it up.

## 7.2 Watch and verify

```bash
kubectl -n devboard-helm get pods -w
kubectl -n devboard-helm get pvc,gateway,httproute
```

## 7.3 Get this deployment's URL

The Helm release names its Gateway `devboard-devboard-gateway` (release name +
chart name):

```bash
kubectl -n devboard-helm get gateway \
  -o jsonpath='{.items[0].status.addresses[0].value}' ; echo
```

Test it just like before:

```bash
ADDR=$(kubectl -n devboard-helm get gateway -o jsonpath='{.items[0].status.addresses[0].value}')
curl -s -o /dev/null -w "frontend: HTTP %{http_code}\n" "http://$ADDR/"
curl -s "http://$ADDR/api/projects"
```

## 7.4 Compare the two

You now have the **same app** deployed two ways:

| | Raw (Step 5) | Helm (Step 7) |
| --- | --- | --- |
| Namespace | `devboard` | `devboard-helm` |
| Source | plain YAML in `k8s/` | chart in `helm/devboard/` |
| Change a value | edit each file | edit one `values.yaml` |
| ArgoCD app | `devboard-raw` | `devboard-helm` |
| Public URL | its own NLB | its own NLB |

That's the lesson: **raw manifests are simplest to read; Helm is easiest to
configure and reuse.** GitOps (ArgoCD) works identically with either.

> 💸 Reminder: running both paths means **two NLBs**. If you only wanted to see
> Helm, delete the raw app: `kubectl delete -f gitops/argocd/devboard-raw.yaml`.

---

✅ Both deployments serve DevBoard from their own URLs.
Next: [`08-cleanup.md`](08-cleanup.md)
