## external-dns

Watches `HTTPRoute` resources and automatically creates Route53 DNS records pointing to the NLB. No manual DNS management needed — adding a hostname to an HTTPRoute is enough.

### Step 1 — Provision IRSA role (Terraform)

```shell
cd terraform/foundation/eks
terraform apply
terraform output external_dns_irsa_arn
```

Paste the ARN into `eks-bootstrap/external-dns/values.yaml` → `serviceAccount.annotations.eks.amazonaws.com/role-arn`.

### Step 2 — Install Helm chart

```shell
CHART_VERSION="1.20.0"
helm repo add external-dns https://kubernetes-sigs.github.io/external-dns/
helm repo update
helm show values external-dns/external-dns --version $CHART_VERSION > eks-bootstrap/external-dns/default-values.yaml

helm install external-dns external-dns/external-dns \
  --version $CHART_VERSION \
  --values eks-bootstrap/external-dns/values.yaml \
  --namespace external-dns \
  --create-namespace
```

### Verify

```shell
kubectl get pods -n external-dns
kubectl logs -n external-dns -l app.kubernetes.io/name=external-dns --tail=50

# After applying an HTTPRoute, the record appears in Route53 within ~1 min
aws route53 list-resource-record-sets \
  --hosted-zone-id <zone-id> \
  --query "ResourceRecordSets[?Name=='gitops.tylerops.dev.']"
```
