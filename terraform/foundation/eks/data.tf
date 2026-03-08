data "aws_ssm_parameter" "argocd_dex_client_secret" {
  name            = "/terraform/eks/argocd_dex_client_secret"
  with_decryption = true
}

data "aws_ssm_parameter" "grafana_oauth_client_secret" {
  name            = "/terraform/eks/grafana_oauth_client_secret"
  with_decryption = true
}
