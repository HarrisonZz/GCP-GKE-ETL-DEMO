# --- 1. Namespaces ---
resource "kubernetes_namespace_v1" "namespaces" {
  # 只保留 argocd 和 monitoring
  for_each = toset(["argocd", "monitoring", "external-secrets"])
  metadata {
    name = each.key
  }
}

# --- 2. ArgoCD ---
resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  namespace  = kubernetes_namespace_v1.namespaces["argocd"].metadata[0].name
  wait       = true

  values = [
    yamlencode({
      server = {
        # GCE Ingress 建議搭配 ClusterIP (GKE 會自動透過 NEG 連接)
        service = { type = "ClusterIP" }

        # 讓 ArgoCD 本體跑在 HTTP 模式
        # 這樣 GCE LB 解密後傳進來的 HTTP 流量才能被正確處理，且 Health Check 才會過
        extraArgs = ["--insecure"]
      }
      # 為了配合 GCE Ingress 建議關閉 TLS 相關強迫設定
      configs = {
        params = {
          "server.insecure" = "true"
        }
      }
    })
  ]
}

# --- 3. ArgoCD Ingress ---
resource "kubernetes_ingress_v1" "argocd_server" {
  metadata {
    name      = "argocd-server"
    namespace = kubernetes_namespace_v1.namespaces["argocd"].metadata[0].name
    annotations = {
      # 1. 指定使用 GKE 原生控制器
      "kubernetes.io/ingress.class" = "gce"

      # 2. 允許 HTTP 存取 (GCE 預設比較嚴格，開發環境建議開啟)
      "kubernetes.io/ingress.allow-http" = "true"

    }
  }

  spec {
    # GCE Ingress 預設需要一個 Default Backend，雖然這裡指定了 rules，
    # 但 GKE 會自動使用 Default Backend 處理 404，通常不需特別設定。
    rule {
      http {
        path {
          # 3. GCE Ingress 的路徑匹配通常需要 /* 才能涵蓋所有子路徑
          path      = "/*"
          path_type = "ImplementationSpecific"
          backend {
            service {
              name = "argocd-server"
              port { number = 80 }
            }
          }
        }
      }
    }
  }

  depends_on = [helm_release.argocd]
}

# --- 4. External Secrets ---
resource "helm_release" "external_secrets" {
  name             = "external-secrets"
  repository       = "https://charts.external-secrets.io"
  chart            = "external-secrets"
  namespace        = kubernetes_namespace_v1.namespaces["external-secrets"].metadata[0].name
  create_namespace = false
  wait             = true

  values = [yamlencode({
    installCRDs = true
  })]
}
