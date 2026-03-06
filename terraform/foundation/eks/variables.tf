variable "argocd_dex_client_secret" {
  description = "Dex OIDC client secret for ArgoCD Authentik integration"
  type        = string
  sensitive   = true
}

variable "grafana_oauth_client_secret" {
  description = "OAuth client secret for Grafana Authentik integration"
  type        = string
  sensitive   = true
}
