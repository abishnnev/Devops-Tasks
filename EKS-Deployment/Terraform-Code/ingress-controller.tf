#############################################
# NGINX Ingress Controller via Helm
#############################################

resource "helm_release" "nginx_ingress" {
  depends_on = [
    module.eks
  ]

  name             = "nginx-ingress"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  namespace        = "ingress-nginx"
  version          = "4.10.1"
  create_namespace = true

  set = [
    {
      name  = "controller.service.type"
      value = "LoadBalancer"
    },
    {
      name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-type"
      value = "nlb"
    }
  ]
}

#############################################
# Output the AWS NLB created by NGINX
#############################################

data "kubernetes_service" "nginx_controller_service" {
  metadata {
    name      = helm_release.nginx_ingress.name
    namespace = helm_release.nginx_ingress.namespace
  }
}
