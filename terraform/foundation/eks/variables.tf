variable "argocd_dex_client_secret" {
  description = "Dex OIDC client secret for ArgoCD Authentik integration"
  type        = string
  sensitive   = true
}
