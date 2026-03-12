Manually update k8sServiceHost in values.yaml file before install cilium.

```bash
helm install cilium oci://quay.io/cilium/charts/cilium \
  --version 1.19.1 \
  --values '/Users/tyler0ps/tylerops.dev/eks-bootstrap/cilium/values.yaml' \
  --namespace 'kube-system'

aws eks delete-addon --cluster-name eks-cilium --addon-name vpc-cni

aws eks delete-addon --cluster-name eks-cilium --addon-name kube-proxy
```