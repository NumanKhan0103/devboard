# ArgoCD is the one workload Terraform installs, and only because it is the
# bootstrap paradox: something has to deploy the thing that deploys everything
# else. After this, Terraform never touches a workload again — every other
# component in this project arrives as an ArgoCD Application committed to Git.

resource "helm_release" "argocd" {
  count = var.enable_argocd ? 1 : 0

  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = var.argocd_chart_version

  namespace        = "argocd"
  create_namespace = true

  # ArgoCD's CRDs are large; server-side apply avoids the 262144-byte limit on
  # the last-applied-configuration annotation that client-side apply uses.
  wait    = true
  timeout = 900

  values = [
    yamlencode({
      configs = {
        params = {
          # Serve plain HTTP instead of self-signed HTTPS. Safe here because
          # the only way in is `kubectl port-forward`, which is already an
          # encrypted tunnel to the API server. A real install terminates TLS
          # at an ingress and drops this.
          "server.insecure" = true
        }
      }

      server = {
        # ClusterIP, not LoadBalancer. A LoadBalancer here is a second AWS NLB
        # at ~$17/month and puts your CD control plane on the public internet
        # behind a password you have not rotated. Use port-forward:
        #   kubectl -n argocd port-forward svc/argocd-server 8080:80
        service = {
          type = "ClusterIP"
        }
      }
    })
  ]

  depends_on = [module.eks]
}
