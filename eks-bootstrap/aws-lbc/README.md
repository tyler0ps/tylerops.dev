## AWS Load Balancer Controller

Provisions the NLB for Envoy Gateway. IAM is managed via Pod Identity (no service account annotation needed). Public subnet tags (`kubernetes.io/role/elb=1`) are managed by Terraform.

### Step 1 — Provision Pod Identity role (Terraform)

```shell
cd terraform/foundation/eks
terraform apply
terraform output vpc_id
```

Paste the VPC ID into `eks-bootstrap/aws-lbc/values.yaml` → `vpcId`.

### Step 2 — Install Helm chart

```shell
CHART_VERSION="3.1.0"
helm repo add eks https://aws.github.io/eks-charts
helm repo update
helm show values eks/aws-load-balancer-controller --version $CHART_VERSION > eks-bootstrap/aws-lbc/default-values.yaml

helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  --version $CHART_VERSION \
  --values eks-bootstrap/aws-lbc/values.yaml \
  --namespace kube-system
```

### Upgrade

```shell
helm upgrade aws-load-balancer-controller eks/aws-load-balancer-controller \
  --version $CHART_VERSION \
  --values eks-bootstrap/aws-lbc/values.yaml \
  --namespace kube-system
```

### Verify

```shell
kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller

# After Envoy Gateway resources are applied, NLB should appear
kubectl get svc -n envoy-gateway-system
aws elbv2 describe-load-balancers --region ap-southeast-1
```
