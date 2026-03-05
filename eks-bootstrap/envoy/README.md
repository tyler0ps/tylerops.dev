## Envoy Gateway

### Step 1 — Install Helm chart

```shell
CHART_VERSION="v1.6.4"
helm show values oci://docker.io/envoyproxy/gateway-helm --version $CHART_VERSION > eks-bootstrap/envoy/default-values.yaml

helm install envoy-gateway oci://docker.io/envoyproxy/gateway-helm \
  --version $CHART_VERSION \
  --values eks-bootstrap/envoy/values.yaml \
  --namespace envoy-gateway-system \
  --create-namespace
```

### Step 2 — Apply Gateway resources

> Requires cert-manager with `tylerops-dev-tls` secret and AWS Load Balancer Controller to be installed first.

```shell
kubectl apply -f eks-bootstrap/envoy/envoyproxy.yaml
kubectl apply -f eks-bootstrap/envoy/gatewayclass.yaml
kubectl apply -f eks-bootstrap/envoy/gateway.yaml
```

AWS LBC will provision an internet-facing NLB automatically.

### Upgrade

```shell
helm upgrade envoy-gateway oci://docker.io/envoyproxy/gateway-helm \
  --version $CHART_VERSION \
  --values eks-bootstrap/envoy/values.yaml \
  --namespace envoy-gateway-system
```

### Verify

```shell
# Controller pods
kubectl get pods -n envoy-gateway-system

# Gateway must be Accepted + Programmed
kubectl get gateway main -n envoy-gateway-system

# NLB DNS name (used by external-dns to create Route53 records)
kubectl get svc -n envoy-gateway-system
```
