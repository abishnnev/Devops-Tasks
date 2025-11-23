resource "helm_release" "authentik" {
  depends_on = [
    helm_release.nginx_ingress, # Wait for ingress controller
    helm_release.velero         # Wait for backup solution
  ]

  name             = "authentik"
  repository       = "https://charts.goauthentik.io/"
  chart            = "authentik"
  namespace        = "authentik"
  version          = "2024.2.1"
  create_namespace = true

  # Helm set values (correct syntax for your provider)
  set = [
    {
      name  = "postgresql.enabled"
      value = "true"
    },
    {
      name  = "redis.enabled"
      value = "true"
    }
  ]

  # Additional values file
  values = [
    file("authentik-values.yaml")
  ]
}
