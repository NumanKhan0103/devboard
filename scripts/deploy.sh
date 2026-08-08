#!/usr/bin/env bash
#
# Deploy everything that runs INSIDE the cluster, in dependency order.
#
# Terraform builds the cluster; this builds what runs on it. Run it after
# `terraform apply` (chapters 02-03) has finished.
#
#   ./scripts/deploy.sh
#
# Safe to re-run: every step is idempotent (helm upgrade --install,
# kubectl apply). If a step times out, fix the cause and run it again.
set -euo pipefail

REGION="${REGION:-us-west-2}"
CLUSTER="${CLUSTER:-devboard}"
EG_VERSION="${EG_VERSION:-v1.2.1}"

cd "$(dirname "$0")/.."

say()  { printf '\n\033[1;36m▶ %s\033[0m\n' "$*"; }
ok()   { printf '\033[1;32m  ✓ %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m  ! %s\033[0m\n' "$*"; }

# --- 0. Preflight ------------------------------------------------------------
# Fail early and loudly rather than half-deploying. Each of these has bitten
# someone: wrong kube context, unpushed branch, missing secret value.

say "Preflight"

for bin in kubectl helm aws git; do
  command -v "$bin" >/dev/null || { echo "missing: $bin"; exit 1; }
done

aws eks update-kubeconfig --name "$CLUSTER" --region "$REGION" >/dev/null
ok "kubeconfig -> $(kubectl config current-context)"

kubectl get nodes >/dev/null
ok "$(kubectl get nodes --no-headers | wc -l | tr -d ' ') nodes reachable"

# ArgoCD pulls manifests from GitHub, not from your laptop. An unpushed commit
# is invisible to it, and the failure mode is a confusing "ComparisonError".
BRANCH="$(git rev-parse --abbrev-ref HEAD)"
if ! git ls-remote --exit-code --heads origin "$BRANCH" >/dev/null 2>&1; then
  echo "Branch '$BRANCH' is not on origin. ArgoCD can only sync what it can fetch."
  echo "  git push -u origin $BRANCH"
  exit 1
fi
if [ -n "$(git log "origin/$BRANCH..$BRANCH" --oneline)" ]; then
  warn "local commits not yet pushed — ArgoCD will deploy the REMOTE state"
fi
ok "branch '$BRANCH' is on origin"

# The app cannot start without this: ESO reads it, and Postgres/backend read
# the Secret that ESO produces.
if ! aws secretsmanager get-secret-value \
      --secret-id devboard/postgres --region "$REGION" >/dev/null 2>&1; then
  echo "Secrets Manager secret 'devboard/postgres' has no value yet."
  echo "Run the 'set_postgres_secret' command from: terraform output"
  exit 1
fi
ok "devboard/postgres has a value"

# --- 1. Envoy Gateway --------------------------------------------------------
# Installs the Gateway API CRDs too, so it must come before anything that
# declares a Gateway or an EnvoyProxy.

say "Envoy Gateway ($EG_VERSION)"
helm upgrade --install eg oci://docker.io/envoyproxy/gateway-helm \
  --version "$EG_VERSION" \
  -n envoy-gateway-system --create-namespace \
  --wait --timeout 10m >/dev/null
ok "controller ready"

kubectl apply -f gitops/gateway/gatewayclass.yaml >/dev/null
ok "GatewayClass 'envoy' applied"

# --- 2. Platform (app-of-apps) ----------------------------------------------
# One Application that creates the rest: External Secrets, the observability
# stack, and Ollama. ArgoCD orders them by sync-wave.

say "Platform: ESO + observability + Ollama"
kubectl apply -f gitops/argocd/platform.yaml >/dev/null
ok "app-of-apps applied — ArgoCD is now creating its children"

# ESO first: nothing else can produce the Postgres Secret.
#
# `kubectl wait` FAILS IMMEDIATELY on an object that does not exist yet — it
# does not wait for it to appear. ArgoCD creates these asynchronously, so we
# have to wait for existence before waiting for readiness. Same for every
# wait_for below.
wait_for() { # wait_for <namespace> <resource> [timeout-seconds]
  local ns="$1" res="$2" limit="${3:-600}" waited=0
  until kubectl -n "$ns" get "$res" >/dev/null 2>&1; do
    [ "$waited" -ge "$limit" ] && return 1
    sleep 10; waited=$((waited + 10))
  done
}

say "Waiting for External Secrets Operator"
if wait_for external-secrets deploy/external-secrets 600 &&
   kubectl -n external-secrets rollout status deploy/external-secrets --timeout=8m >/dev/null 2>&1; then
  ok "ESO ready"
else
  warn "not ready — check: kubectl -n argocd get app external-secrets"
fi

# --- 3. The application ------------------------------------------------------
# Left as an explicit apply rather than folded into the app-of-apps: chapters
# 07 and 09 teach registering an Application by hand, and running both stacks
# side by side is how you compare raw manifests against Helm.

say "DevBoard (raw manifests -> namespace 'devboard')"
kubectl apply -f gitops/argocd/devboard-raw.yaml >/dev/null
ok "devboard-raw applied"

# Uncomment for the second stack. Costs a second NLB (~$17/mo).
# kubectl apply -f gitops/argocd/devboard-helm.yaml >/dev/null

# --- 4. Verify ---------------------------------------------------------------

say "Waiting for the app to settle"

# Expect pods to sit in CreateContainerConfigError for a moment on first boot:
# they start before ESO has produced devboard-secrets. This is self-healing —
# kubelet retries, ESO catches up. See gitops/06-secrets-with-secrets-manager.md.
if wait_for devboard deploy/devboard-backend-deployment 600 &&
   kubectl -n devboard wait --for=condition=available --timeout=10m \
     deploy/devboard-backend-deployment deploy/devboard-frontend-deployment >/dev/null 2>&1; then
  ok "backend and frontend available"
else
  warn "app not ready — see the PVC/secret checks below"
fi

say "Status"

echo "--- ArgoCD applications ---"
kubectl -n argocd get applications \
  -o custom-columns=NAME:.metadata.name,SYNC:.status.sync.status,HEALTH:.status.health.status 2>/dev/null

echo
echo "--- PersistentVolumeClaims (all must be Bound, not Pending) ---"
kubectl get pvc -A 2>/dev/null

echo
echo "--- the Secret ESO built from AWS ---"
kubectl -n devboard get secret devboard-secrets \
  -o jsonpath='{.data}' 2>/dev/null | tr ',' '\n' | cut -d'"' -f2 | sed 's/^/    /'

echo
echo "--- pods ---"
kubectl get pods -n devboard -n ollama -A 2>/dev/null \
  | grep -E 'NAMESPACE|devboard|ollama|observability' | head -30

# The Gateway's address is assigned by AWS and takes a minute or two after the
# Gateway is accepted.
say "Public URL"
for i in $(seq 1 30); do
  ADDR="$(kubectl -n devboard get gateway devboard-gateway \
          -o jsonpath='{.status.addresses[0].value}' 2>/dev/null || true)"
  [ -n "$ADDR" ] && break
  sleep 10
done

if [ -n "${ADDR:-}" ]; then
  ok "http://$ADDR"
  echo
  echo "    curl -s http://$ADDR/api/projects | head -c 200"
  echo "    curl -N -X POST http://$ADDR/api/ai/ask \\"
  echo "      -H 'content-type: application/json' \\"
  echo "      -d '{\"project_id\":\"1\",\"question\":\"what is blocked?\"}'"
  echo
  echo "    kubectl -n observability port-forward svc/grafana 3000:80"
else
  warn "Gateway has no address yet: kubectl -n devboard get gateway devboard-gateway"
fi

say "Done. Tear down with gitops/15-cleanup.md — namespaces BEFORE terraform destroy."
