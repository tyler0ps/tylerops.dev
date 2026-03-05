## ArgoCD

Exposed via Envoy Gateway HTTPRoute at `https://gitops.tylerops.dev`. SSO via Authentik OIDC. TLS terminated at the Gateway.

### Prerequisites

The following must be running before installing ArgoCD:
- cert-manager with `tylerops-dev-tls` secret in `envoy-gateway-system`
- AWS Load Balancer Controller
- Envoy Gateway with GatewayClass + Gateway applied
- external-dns

---

### Step 1 — Authentik: Create OAuth2 Provider

In the Authentik admin UI (`https://auth.tylerops.dev`):

1. **Create OAuth2/OpenID Provider**
   - Admin → Applications → Providers → Create → OAuth2/OpenID Provider
   - Name: `argocd`
   - Client type: `Confidential`
   - Redirect URIs: `https://gitops.tylerops.dev/api/dex/callback`, `https://localhost:8085/auth/callback`
   - Post-logout redirect URI: `https://gitops.tylerops.dev/logout`
   - Signing key: select existing key
   - Copy **Client ID** and **Client Secret**

2. **Add scopes** — Provider → Edit → Advanced Protocol Settings → Scopes:
   - Add: `profile`, `email`, `groups` mappings

3. **Create Application**
   - Applications → Applications → Create
   - Name: `ArgoCD`, Slug: `argocd`
   - Provider: `argocd`

4. **Create group** — Directory → Groups → Create → Name: `argocd-admins`, add your user

5. **Update `values.yaml`** — paste the Client ID into `configs.cm.dex.config.clientID`

---

### Step 2 — Install Helm chart

```shell
CHART_VERSION="9.4.7"
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update
helm show values argo/argo-cd --version $CHART_VERSION > eks-bootstrap/argo/default-values.yaml
```

Install (replace `<client-secret>` with the secret from Step 1):

```shell
helm install argocd argo/argo-cd \
  --version $CHART_VERSION \
  --values eks-bootstrap/argo/values.yaml \
  --set-json 'configs.secret.extra={"dex.authentik.clientSecret":"<client-secret>"}' \
  --namespace argocd \
  --create-namespace
```

### Step 3 — Apply HTTPRoute

```shell
kubectl apply -f eks-bootstrap/argo/httproute.yaml
# external-dns will create gitops.tylerops.dev in Route53 automatically
```

### Upgrade

```shell
helm upgrade argocd argo/argo-cd \
  --version $CHART_VERSION \
  --values eks-bootstrap/argo/values.yaml \
  --set-json 'configs.secret.extra={"dex.authentik.clientSecret":"<client-secret>"}' \
  --namespace argocd
```

---

### Verify

```shell
kubectl get pods -n argocd

kubectl get gateway main -n envoy-gateway-system
# PROGRAMMED=True

kubectl get httproute argocd -n argocd

# Browser: https://gitops.tylerops.dev → Log In via Authentik (via DEX)
# CLI: argocd login gitops.tylerops.dev --sso
```
