# DevBoard on EKS — a GitOps journey with ArgoCD, Helm & the Gateway API

Welcome! 👋 This folder turns DevBoard (our little React + Go + Postgres task
tracker) into a **real cloud deployment** you can build with your own hands.

By the end you will have:

- An **EKS** cluster created with **eksctl** — one YAML file, no Terraform.
- **Envoy Gateway** giving the app a public URL through the **Gateway API**.
- **ArgoCD** doing GitOps: it watches this Git branch and deploys the app for you.
- The same app deployed **two ways** so you can feel the difference:
  1. **Without Helm** — ArgoCD applies the raw manifests in [`../k8s/`](../k8s/).
  2. **With Helm** — ArgoCD renders our chart in [`../helm/devboard/`](../helm/devboard/).

No prior GitOps experience needed. Each step lives in its own file and is meant
to be read top-to-bottom.

---

## The big picture

```
        you push to Git (branch: gitops)
                    │
                    ▼
   ┌─────────────────────────────────┐
   │            ArgoCD               │  watches the repo, syncs the cluster
   └─────────────────────────────────┘
                    │ deploys
                    ▼
   ┌─────────────────────────────────┐
   │   EKS cluster (created by eksctl)│
   │                                 │
   │   Internet ──▶ Envoy Gateway ──▶ frontend ──/api──▶ backend ──▶ postgres
   │                (AWS NLB)         (React)            (Go/Gin)    (StatefulSet)
   └─────────────────────────────────┘
```

One thing worth knowing up front: the **frontend already proxies `/api` to the
backend internally**. That is why the Gateway only needs to point at the
frontend — traffic to the backend stays inside the cluster.

---

## Follow the steps in order

| Step | File | What you do |
| --- | --- | --- |
| 0 | **this file** | Understand the plan |
| 1 | [`01-prerequisites.md`](01-prerequisites.md) | Install eksctl / kubectl / helm / awscli, configure AWS |
| 2 | [`02-create-eks.md`](02-create-eks.md) | Create the EKS cluster + storage add-on |
| 3 | [`03-gateway-api.md`](03-gateway-api.md) | Install Envoy Gateway, create the GatewayClass |
| 4 | [`04-argocd.md`](04-argocd.md) | Install ArgoCD, log in |
| 5 | [`05-deploy-without-helm.md`](05-deploy-without-helm.md) | Deploy the raw manifests via ArgoCD |
| 6 | [`06-package-with-helm.md`](06-package-with-helm.md) | Tour the Helm chart, render it locally |
| 7 | [`07-deploy-with-helm.md`](07-deploy-with-helm.md) | Deploy the chart via ArgoCD |
| 8 | [`08-cleanup.md`](08-cleanup.md) | Tear everything down so you stop paying |

---

## 💸 Cost & safety — please read

EKS is **not free**. While this cluster runs you pay for:

- the EKS control plane (~$0.10/hour),
- 2 × `t3.medium` worker nodes,
- one **AWS NLB per Gateway** (each deployment path creates its own Gateway),
- a small EBS volume for Postgres.

Rough order of magnitude: **a few US dollars per day**. That is fine for a day of
learning, but **do [`08-cleanup.md`](08-cleanup.md) when you are done.** You can
also run just one of the two deployment paths to save one NLB.

---

## Repo layout this journey adds

```
gitops/
  01..08-*.md            step-by-step docs (this journey)
  eksctl/cluster.yaml    the EKS cluster definition
  gateway/gatewayclass.yaml   ties the name "envoy" to the controller
  argocd/
    install-values.yaml  Helm values for ArgoCD itself
    devboard-raw.yaml     ArgoCD App → raw k8s/ manifests
    devboard-helm.yaml    ArgoCD App → helm/devboard chart

helm/devboard/           the DevBoard Helm chart (values.yaml + templates/)
k8s/                     the raw manifests (now with gateway.yml + httproute.yml)
```

Ready? Start with [`01-prerequisites.md`](01-prerequisites.md).
