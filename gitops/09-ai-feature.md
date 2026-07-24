# Step 9 — Add an AI Assistant (self-hosted, free)

DevBoard can now **summarise a project** and **answer questions** about its
tasks — with the answer streaming in token-by-token. The whole thing runs
**inside your cluster**, so it's free: no API key, no per-token bill.

## What we added

```
browser ─▶ Envoy Gateway ─▶ frontend (AI Assistant page at /ai)
                              └─ /api/ai/*  → ai-service  ── OpenAI-style ──▶  Ollama
                                                 │                            (llama3.2:1b, CPU)
                                                 └─ fetches task context from the backend
```

- **`ai-service/`** — a small Python/Flask service. On each request it pulls the
  project's tasks from the backend, builds a grounded prompt, and **streams** the
  model's reply back as Server-Sent Events. Endpoints: `POST /api/ai/summarise`,
  `POST /api/ai/ask`.
- **Ollama** (`gitops/ollama/`) — a shared, in-cluster model server running
  **`llama3.2:1b`**. It speaks the OpenAI API, so the ai-service talks to it with
  ordinary OpenAI-style calls. Deployed once as platform infra (like Envoy
  Gateway) and shared by every app stack.
- **Frontend** — a new **AI Assistant** page (`/ai`) with a project picker,
  "Summarise project" button, and a chat box.

## ⚖️ The honest trade-off

A *truly* powerful model (70B+) needs a GPU or lots of RAM — not free. On our
CPU-only `t3.medium` nodes we run a **small** model (`llama3.2:1b`). It's real,
free, and self-contained, but:

- answers are **modest quality** compared to a frontier model, and
- CPU inference is **slower** (and the very first request waits for Ollama to
  pull ~1.3 GB and load the model).

Want it better? Two options (see the end of this doc): a bigger/GPU node, or
point the ai-service at a **free hosted API** instead.

## Deploy it

The node group already runs 3 nodes (`gitops/eksctl/cluster.yaml`) to give
Ollama headroom. If you built the cluster with the old 2-node config, scale up:

```bash
eksctl scale nodegroup --cluster devboard --name ng-default --nodes 3 --region us-west-2
```

1. **Deploy the shared Ollama** (its own ArgoCD app):
   ```bash
   kubectl apply -f gitops/argocd/ollama.yaml
   # first boot pulls the model — give it a few minutes
   kubectl -n ollama rollout status deploy/ollama --timeout=600s
   kubectl -n ollama exec deploy/ollama -- ollama list   # shows llama3.2:1b
   ```
2. **The app stacks pick up the ai-service automatically** — it's part of both the
   raw manifests (`k8s/`) and the Helm chart, so ArgoCD deploys it on the next
   sync. Force a refresh if you're impatient:
   ```bash
   kubectl -n argocd annotate app devboard-raw devboard-helm \
     argocd.argoproj.io/refresh=hard --overwrite
   ```

## Try it

```bash
ADDR=$(kubectl -n devboard get gateway devboard-gateway -o jsonpath='{.status.addresses[0].value}')

# stream a project summary (‑N = no buffering, so you see tokens arrive)
curl -N http://$ADDR/api/ai/summarise \
  -H 'content-type: application/json' -d '{"project_id":"1"}'

# ask a question
curl -N http://$ADDR/api/ai/ask \
  -H 'content-type: application/json' \
  -d '{"project_id":"1","question":"What is blocked and why?"}'
```

Or open **`http://$ADDR/ai`** in the browser and use the AI Assistant page.

Health/diagnostics:
```bash
curl http://$ADDR/api/ai/health        # {"status":"ok","model":"llama3.2:1b"}
kubectl -n devboard exec deploy/devboard-ai-service-deployment -- \
  curl -s localhost:3005/model/check   # is the model loaded & reachable?
```

## Making it more powerful

- **Swap the model:** edit `OLLAMA_MODEL` in `gitops/ollama/deployment.yml`
  (e.g. `llama3.2:3b`, `gemma2:2b`) and `MODEL_NAME` in the ai-service env /
  Helm `ai.modelName`. Bigger models need more RAM — bump the node instance type
  (e.g. a dedicated `t3.large`/`t3.xlarge` node group) accordingly.
- **Use a free hosted API instead of Ollama:** the ai-service already supports
  it. Set `MODEL_API_BASE` to the provider's OpenAI-compatible URL, `MODEL_NAME`
  to their model, and `MODEL_API_KEY` to your key (e.g. Groq's
  `https://api.groq.com/openai/v1` + `llama-3.3-70b-versatile`). Put the key in a
  Secret — **never** commit it (this repo is public and ArgoCD syncs from it).

---

✅ `http://$ADDR/ai` streams a project summary from the in-cluster model.
Back to the [README](README.md) · when you're done, [`08-cleanup.md`](08-cleanup.md).
