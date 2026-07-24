# Step 6 — Package DevBoard WITH Helm

The raw manifests work, but they're rigid: image tags, replica counts, and the
DB password are all hard-coded across many files. **Helm** lets us package the
same app as a chart with one **`values.yaml`** you can tune per environment.

The chart lives in [`../helm/devboard/`](../helm/devboard/).

## 6.1 Chart layout

```
helm/devboard/
  Chart.yaml           chart name + version
  values.yaml          every knob (images, replicas, resources, DB creds, gateway)
  files/               the Postgres init SQL (schema + seed)
  templates/
    _helpers.tpl       shared name/label snippets
    configmap.yaml     POSTGRES_USER + the init SQL ConfigMap
    secret.yaml        POSTGRES_PASSWORD/DB + the assembled POSTGRES_URL
    postgres-*.yaml    StatefulSet + headless Service
    backend-*.yaml     Deployment + Service (name stays "backend")
    frontend-*.yaml    Deployment + Service + HPA
    gateway.yaml       Gateway   (toggle with gateway.enabled)
    httproute.yaml     HTTPRoute (/ → frontend)
    NOTES.txt          printed after install — tells you how to get the URL
```

## 6.2 The important values

Open [`values.yaml`](../helm/devboard/values.yaml). Highlights:

```yaml
postgres:
  password: devboard          # DEMO ONLY — never commit real secrets
  storage:
    size: 1Gi
    storageClassName: ""      # "" = cluster default (gp2 on EKS)

backend:
  serviceName: backend        # keep it "backend": the frontend proxy targets it
  port: 8080

frontend:
  hpa: { enabled: true, minReplicas: 1, maxReplicas: 5 }

gateway:
  enabled: true               # set false to skip the Gateway (e.g. local cluster)
  className: envoy
```

Two things worth understanding:

- **The backend reads a single `POSTGRES_URL`.** `secret.yaml` assembles it from
  `postgres.user/password/db` so there's one source of truth — change the
  password once and everything follows.
- **`backend.serviceName` must stay `backend`.** The frontend image has
  `http://backend:8080` baked into its proxy config, so renaming the Service
  would break the UI's `/api` calls.

## 6.3 Render it locally (no cluster needed)

This is the best way to *see* what Helm produces before deploying:

```bash
# lint for mistakes
helm lint helm/devboard

# render the templates to plain YAML and read it
helm template devboard helm/devboard --namespace devboard-helm | less

# try an override — notice the replica count change in the output
helm template devboard helm/devboard --set frontend.replicas=3 | grep -A2 "replicas"
```

`helm template` is exactly what ArgoCD runs under the hood for a Helm source —
so if it renders cleanly here, ArgoCD will be happy too.

## 6.4 (Optional) install with the Helm CLI directly

You *could* skip ArgoCD and install straight away:

```bash
helm install devboard helm/devboard --namespace devboard-helm --create-namespace
```

But in the next step we'll let **ArgoCD** manage the chart instead — that's the
GitOps way, and it's the point of this exercise. If you ran the command above,
undo it first: `helm uninstall devboard -n devboard-helm`.

---

✅ `helm lint` passes and `helm template` renders the full app.
Next: [`07-deploy-with-helm.md`](07-deploy-with-helm.md)
