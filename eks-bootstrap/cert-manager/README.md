## cert-manager

Manages TLS certificates via Let's Encrypt DNS-01 (Route53). Issues a wildcard cert `*.tylerops.dev` stored in `envoy-gateway-system/tylerops-dev-tls`, used by Envoy Gateway.

### Step 1 — Provision IRSA role (Terraform)

```shell
cd terraform/foundation/eks
terraform apply
terraform output cert_manager_irsa_arn
```

Paste the ARN into `eks-bootstrap/cert-manager/values.yaml` → `serviceAccount.annotations.eks.amazonaws.com/role-arn`.

### Step 2 — Install Helm chart

```shell
CHART_VERSION="v1.19.4"
helm repo add jetstack https://charts.jetstack.io
helm repo update
helm show values jetstack/cert-manager --version $CHART_VERSION > eks-bootstrap/cert-manager/default-values.yaml

helm install cert-manager jetstack/cert-manager \
  --version $CHART_VERSION \
  --values eks-bootstrap/cert-manager/values.yaml \
  --namespace cert-manager \
  --create-namespace
```

### Step 3 — Apply ClusterIssuer and Certificate

```shell
kubectl apply -f eks-bootstrap/cert-manager/clusterissuer.yaml
kubectl apply -f eks-bootstrap/cert-manager/certificate.yaml
```

### Verify

```shell
kubectl get pods -n cert-manager

# ClusterIssuer must be Ready=True
kubectl get clusterissuer letsencrypt-prod

# Certificate issued in ~1-2 min
kubectl get certificate tylerops-dev-tls -n envoy-gateway-system

# Secret available once issued
kubectl get secret tylerops-dev-tls -n envoy-gateway-system
```
