# Step 3 — Gateway API with Envoy Gateway

The **Gateway API** is the modern successor to Ingress. Instead of one big
annotated Ingress object, it splits responsibilities cleanly:

- **GatewayClass** — "which controller handles my gateways?" (cluster-wide, set once)
- **Gateway** — "give me a load balancer listening on port 80" (creates an AWS NLB)
- **HTTPRoute** — "send `/` to this Service" (the routing rules)

We'll use **Envoy Gateway** as the controller.

## 3.1 Install Envoy Gateway (with Helm)

```bash
helm install eg oci://docker.io/envoyproxy/gateway-helm \
  --version v1.2.1 \
  --namespace envoy-gateway-system --create-namespace

# wait for it to come up
kubectl -n envoy-gateway-system rollout status deploy/envoy-gateway
```

> Tip: `v1.2.1` was current when this was written — check the
> [releases page](https://github.com/envoyproxy/gateway/releases) and use the
> latest stable if you like. Installing Envoy Gateway also installs the standard
> **Gateway API CRDs** (`Gateway`, `HTTPRoute`, `GatewayClass`) for you.

## 3.2 Create the GatewayClass

This one-time, cluster-scoped object links the name **`envoy`** (used by every
Gateway in this repo) to the controller:

```bash
kubectl apply -f gitops/gateway/gatewayclass.yaml
kubectl get gatewayclass envoy       # should show ACCEPTED = True
```

## 3.3 How this connects to the app

You do **not** create the Gateway/HTTPRoute by hand — they ship *with* the app:

- The raw path has [`../k8s/gateway.yml`](../k8s/gateway.yml) +
  [`../k8s/httproute.yml`](../k8s/httproute.yml).
- The Helm chart templates the same two objects
  ([`gateway.yaml`](../helm/devboard/templates/gateway.yaml) /
  [`httproute.yaml`](../helm/devboard/templates/httproute.yaml)).

So when ArgoCD deploys DevBoard (next steps), each deployment automatically gets
its **own** Gateway → its own AWS NLB → its own public URL.

> Both HTTPRoutes send `/` to the frontend Service. The frontend proxies `/api`
> to the backend inside the cluster. Each file also has a commented **advanced**
> example that routes `/api` straight to the backend using a `URLRewrite` filter —
> a nice way to see Gateway API filters in action once you're comfortable.

---

✅ `kubectl get gatewayclass envoy` shows `Accepted=True`.
Next: [`04-argocd.md`](04-argocd.md)
