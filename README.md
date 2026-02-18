# wp-hugo-static

A reusable, open-source harness that turns WordPress into a static site using Hugo, deployed to Cloudflare Pages.

## Features

- **Self-hosted WordPress** with Caddy reverse proxy
- **Caddy** with Cloudflare ACME DNS challenge for automatic SSL
- **WUD (What's Up Docker)** for semi-automatic container updates
- **Hugo** with Stack theme (via Hugo Modules, not git submodules)
- **Giscus** comments via GitHub Discussions
- **GitHub Actions** CI/CD pipeline
- **Hybrid content**: WordPress posts/pages + custom Hugo pages

## Architecture

```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐
│  WordPress      │────▶│  GitHub Actions  │────▶│  Cloudflare     │
│  (Caddy Proxy)  │     │  (Build & Deploy)│     │  Pages          │
└─────────────────┘     └──────────────────┘     └─────────────────┘
        │
        ▼
┌─────────────────┐
│  Caddy + WUD    │
│  (SSL + Updates)│
└─────────────────┘
```

## Prerequisites

- Docker and Docker Compose
- Cloudflare account (for DNS and Pages)
- GitHub account (for CI/CD and Giscus)
- Go (for Hugo Modules)
- Hugo Extended (for Stack theme)
- Ruby 3.4+ (for conversion scripts)

### Installing Prerequisites

**macOS:**
```bash
brew install go hugo ruby
```

**Linux:**
```bash
# Go
sudo apt install golang-go

# Hugo Extended
wget https://github.com/gohugoio/hugo/releases/download/v0.123.0/hugo_extended_0.123.0_linux-amd64.tar.gz
tar -xzf hugo_extended_*.tar.gz
sudo mv hugo /usr/local/bin/

# Ruby
sudo apt install ruby-full
```

## Quick Start

### 1. Clone and Configure

```bash
git clone https://github.com/yourusername/wp-hugo-static.git
cd wp-hugo-static
./setup.sh
```

The setup script will prompt for:
- Domain name (e.g., `wordpress.yourdomain.com`)
- Cloudflare API token and account ID
- GitHub repository and token
- Site title and author info
- Giscus configuration

### 2. Start WordPress

```bash
docker compose up -d --build
```

### 3. Complete WordPress Setup

1. Access WordPress at your configured domain: `https://yourdomain.com`
2. Complete the WordPress installation wizard
3. Create some test posts

### 4. Configure GitHub Secrets

Go to your repository → Settings → Secrets and variables → Actions

Add the following secrets:
- `CLOUDFLARE_API_TOKEN` - Cloudflare API token
- `CLOUDFLARE_ACCOUNT_ID` - Your Cloudflare account ID
- `CLOUDFLARE_PAGES_PROJECT` - Cloudflare Pages project name
- `WP_API_URL` - Your WordPress REST API URL
- `GITHUB_TOKEN` - GitHub Personal Access Token (for webhook)

### 5. Deploy

```bash
# Trigger a build
gh workflow run deploy.yml

# Or push to main branch
git push origin main
```

### 6. Set Up Giscus

1. Enable GitHub Discussions on your repository
2. Install the Giscus app: https://github.com/apps/giscus
3. Get your repo ID and category ID from https://giscus.app/

### Optional: Secure with Tailscale

For enhanced security, you can restrict WordPress admin access to your private network using Tailscale:

1. Install Tailscale on your server: https://tailscale.com/download
2. Configure Magic DNS for a private domain (e.g., `wordpress.your-tailnet.ts.net`)
3. Update your `.env` file with the Tailscale domain
4. Only devices on your Tailscale network can access WordPress admin

This prevents your WordPress admin from being publicly accessible while still allowing the static site to be public.

## Configuration

### Environment Variables

See `.env.example` for all configuration options:

| Variable | Description |
|----------|-------------|
| `DOMAIN` | WordPress domain |
| `CLOUDFLARE_API_TOKEN` | Cloudflare API token for ACME |
| `ACME_EMAIL` | Email for SSL certificates |
| `DB_PASSWORD` | WordPress database password |
| `GITHUB_TOKEN` | GitHub PAT for webhooks |
| `GISCUS_REPO` | GitHub repo for comments |

### Hybrid Content

wp-hugo-static supports three content types:

1. **WordPress Posts** - Blog content, imported automatically
2. **WordPress Pages** - Static pages, imported automatically
3. **Custom Hugo Pages** - Hand-coded pages with custom layouts

See `docs/hybrid-content.md` for details.

## File Structure

```
wp-hugo-static/
├── docker-compose.yml      # Docker services
├── Dockerfile.caddy        # Custom Caddy build
├── Caddyfile              # Caddy configuration
├── .env.example           # Environment template
├── setup.sh               # Setup script
├── backup.sh              # Backup script
├── restore.sh             # Restore script
├── hugo-site/             # Hugo static site
│   ├── hugo.toml          # Hugo configuration
│   ├── go.mod             # Hugo Modules
│   ├── content/           # Markdown content
│   ├── layouts/           # Custom layouts
│   └── static/            # Static files
├── scripts/               # Conversion scripts
│   ├── fetch-posts.rb     # WP posts → Hugo
│   ├── fetch-pages.rb     # WP pages → Hugo
│   ├── fetch-images.rb    # Download images
│   ├── wp-webhook.php     # WP webhook code
│   └── Gemfile            # Ruby dependencies
├── .github/workflows/     # GitHub Actions
│   └── deploy.yml         # CI/CD pipeline
└── docs/                  # Documentation
    └── hybrid-content.md  # Content strategy
```

## Backup and Restore

### Backup

```bash
./backup.sh
```

Backs up:
- WordPress database
- `wp-content` directory (uploads, plugins, themes)

### Restore

```bash
./restore.sh db_20240101_023000.sql.gz wp-content_20240101_023000.tar.gz
```

## Container Updates

WUD (What's Up Docker) automatically checks for container updates daily at 3:00 AM.

Access the WUD dashboard at `http://your-server:3000` (Tailscale only).

## Troubleshooting

### WordPress not accessible

1. Check Tailscale is running: `tailscale status`
2. Verify DNS: `dig wordpress.yourdomain.com`
3. Check container logs: `docker compose logs wordpress`

### Build fails

1. Check GitHub Actions logs
2. Verify all secrets are set
3. Test locally: `cd hugo-site && hugo`

### Images not loading

1. Run `ruby scripts/fetch-images.rb` manually
2. Check `hugo-site/static/images/` directory
3. Verify image paths in content

## Contributing

Contributions are welcome! Please read our contributing guidelines before submitting a pull request.

## License

MIT License - see LICENSE file for details.