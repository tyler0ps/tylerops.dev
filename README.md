# tylerops.dev

Source code for [https://tylerops.dev](https://tylerops.dev) - Personal website and blog built with VitePress, hosted on AWS.

## Tech Stack

- **Static Site Generator**: VitePress
- **Hosting**: AWS S3 + CloudFront
- **SSL**: AWS ACM
- **DNS**: AWS Route53
- **CI/CD**: GitHub Actions (OIDC)

## Development

```bash
# Install dependencies
npm install

# Start dev server
npm run dev

# Build for production
npm run build

# Preview production build
npm run preview
```

## Deployment

Push to `main` branch with changes in `docs/**` triggers automatic deployment via GitHub Actions.

The workflow expects these GitHub repo variables to be set:
- `AWS_ROLE_ARN` - IAM role for OIDC auth
- `S3_BUCKET` - Target S3 bucket name
- `CLOUDFRONT_DISTRIBUTION_ID` - CloudFront distribution to invalidate

## Project Structure

```
├── docs/                   # VitePress content
│   ├── .vitepress/         # VitePress config
│   ├── index.md            # Homepage
│   ├── about.md            # About page
│   ├── blog/               # Blog posts
│   └── projects/           # Projects page
├── source/                 # DevOps materials (Terraform/K8s code)
│   └── eks-karpenter/      # EKS + Karpenter setup
└── .github/workflows/      # CI/CD pipelines
```

## License

MIT
