# ============================================================
# TLS CERTIFICATE PERSISTENCE
#
# Backs up the wildcard TLS cert (*.tylerops.dev) to S3 on cluster
# destroy, restores on startup.
#
# This avoids hitting Let's Encrypt's rate limit of 5 duplicate
# certificates/week when the cluster is frequently recreated.
#
# Storage: s3://generic-gha-terraform-state/eks-foundation/tls/tylerops-dev-tls.json
# Cost: free (negligible S3 storage for ~10KB JSON)
#
# Flow:
#   destroy: tls_cert_backup runs → saves to S3 → cluster gone
#   apply:   tls_cert_restore runs → pre-populates k8s secret →
#            cert-manager sees valid secret → skips re-issuance
# ============================================================

locals {
  tls_s3_bucket = "generic-gha-terraform-state"
  tls_s3_key    = "eks-foundation/tls/tylerops-dev-tls.json"
}

# RESTORE: pre-populate the tylerops-dev-tls k8s Secret from S3
# before cert-manager applies the Certificate CR. cert-manager will
# adopt the existing valid secret without re-issuing.
resource "null_resource" "tls_cert_restore" {
  triggers = {
    cluster_name = module.eks_karpenter.cluster_name
  }

  provisioner "local-exec" {
    command = <<-EOT
      CERT_JSON=$(aws s3 cp \
        s3://${local.tls_s3_bucket}/${local.tls_s3_key} - \
        --region ${local.region} 2>/dev/null) || exit 0
      [ -z "$CERT_JSON" ] && { echo "No TLS backup found, cert-manager will issue fresh cert."; exit 0; }
      TLS_CRT=$(echo "$CERT_JSON" | jq -r '."tls.crt"')
      TLS_KEY=$(echo "$CERT_JSON" | jq -r '."tls.key"')
      [ -z "$TLS_CRT" ] || [ "$TLS_CRT" = "null" ] && exit 0
      kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: tylerops-dev-tls
  namespace: envoy-gateway-system
type: kubernetes.io/tls
data:
  tls.crt: $TLS_CRT
  tls.key: $TLS_KEY
EOF
      echo "TLS cert restored from S3."
    EOT
  }

  depends_on = [helm_release.envoy_gateway]
}

# BACKUP: save cert to S3 before the cluster is destroyed.
# Destroy order (enforced via depends_on):
#   1. null_resource.tls_cert_backup destroyed → backup provisioner runs
#   2. kubectl_manifest.certificate_tylerops_dev destroyed
#   3. helm releases destroyed
resource "null_resource" "tls_cert_backup" {
  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      TLS_CRT=$(kubectl get secret tylerops-dev-tls \
        -n envoy-gateway-system \
        -o jsonpath='{.data.tls\.crt}' 2>/dev/null) || exit 0
      TLS_KEY=$(kubectl get secret tylerops-dev-tls \
        -n envoy-gateway-system \
        -o jsonpath='{.data.tls\.key}' 2>/dev/null) || exit 0
      [ -z "$TLS_CRT" ] && { echo "Secret not found, skipping backup."; exit 0; }
      echo "{\"tls.crt\":\"$TLS_CRT\",\"tls.key\":\"$TLS_KEY\"}" | \
        aws s3 cp - s3://generic-gha-terraform-state/eks-foundation/tls/tylerops-dev-tls.json \
          --region ap-southeast-1
      echo "TLS cert backed up to S3."
    EOT
  }

  depends_on = [kubectl_manifest.certificate_tylerops_dev]
}
