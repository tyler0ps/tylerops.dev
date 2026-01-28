# OceanCloud.click

Personal website and blog built with VitePress, hosted on AWS.

## Tech Stack

- **Static Site Generator**: VitePress
- **Hosting**: AWS S3 + CloudFront
- **SSL**: AWS ACM
- **DNS**: AWS Route53
- **Infrastructure**: Terraform
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

### Infrastructure Setup (One-time)

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

After applying, note the outputs:
- `github_actions_role_arn` - Add as `AWS_ROLE_ARN` in GitHub repo variables
- `cloudfront_distribution_id` - Add as `CLOUDFRONT_DISTRIBUTION_ID` in GitHub repo variables

### Automatic Deployment

Push to `main` branch with changes in `docs/**` triggers automatic deployment via GitHub Actions.

## Project Structure

```
├── docs/                    # VitePress content
│   ├── .vitepress/         # VitePress config
│   ├── index.md            # Homepage
│   ├── about.md            # About page
│   ├── blog/               # Blog posts
│   └── projects/           # Projects page
├── terraform/              # Infrastructure as Code
└── .github/workflows/      # CI/CD pipelines
```

## License

MIT
