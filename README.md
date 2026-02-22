# wp-hugo-static

A reusable, open-source harness that turns WordPress into a static site using Hugo, deployed to Cloudflare Pages.

## Features

- **Self-hosted WordPress** (direct access or reverse proxy)
- **Hugo** with Stack theme (via Hugo Modules)
- **Giscus** comments via GitHub Discussions
- **Baked Comments** - Comments fetched at build time, baked into static HTML for SEO
- **GitHub Actions** CI/CD pipeline
- **Hybrid content**: WordPress posts/pages + custom Hugo pages

## Architecture

```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐
│  WordPress      │────▶│  GitHub Actions  │────▶│  Cloudflare     │
│                 │     │  (Build & Deploy)│     │  Pages          │
└─────────────────┘     └──────────────────┘     └─────────────────┘
```

## Prerequisites

- Docker and Docker Compose
- Cloudflare account (for DNS and Pages)
- GitHub account (for CI/CD and Giscus)

### Installing Prerequisites

This project uses **Homebrew** as the package manager for all platforms (macOS and Linux).

**All Platforms:**
```bash
# Install Homebrew if not already installed
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install Docker
brew install --cask docker
```

All other tools (Ruby, Hugo, Go) run via the builder container - no need to install them locally!

### Running Tools via Docker

```bash
# Start builder container
docker compose up -d wordpress db builder

# Ruby scripts (via builder container)
docker compose exec -e WP_API_URL=http://wordpress/wp-json/wp/v2 \
  -e WP_USERNAME=admin -e WP_APPLICATION_PASSWORD=xxx \
  builder ruby scripts/ensure-archived-category.rb

# Hugo (via builder container - pre-installed)
docker compose exec builder hugo -s /app/hugo-site --minify
```

**Important**: When running scripts inside the builder container, use `http://wordpress` (Docker hostname), NOT `http://localhost:8888`.

## Quick Start

### Prerequisites: Get Your Cloudflare Credentials

Before running `setup.sh`, you'll need Cloudflare credentials. Here's how to get them:

#### 1. Get Your Cloudflare Account ID

1. Log in to [Cloudflare Dashboard](https://dash.cloudflare.com)
2. Look at the right sidebar - your **Account ID** is displayed there
3. Copy this value for later

#### 2. Create a Cloudflare API Token

1. Go to [Cloudflare API Tokens](https://dash.cloudflare.com/profile/api-tokens)
2. Click **"Create Token"**
3. Use the **"Cloudflare Pages"** template or create a custom token with:
   - **Account** → **Cloudflare Pages** → **Edit**
4. Select your account and continue
5. Click **"Create Token"** and **copy it immediately** - you won't see it again!

#### 3. Create a Cloudflare Pages Project

1. In the Cloudflare Dashboard, go to **Pages** → **Create a project**
2. Choose **"Upload assets"** (not "Connect to Git")
3. Enter a project name (e.g., `your-blog`)
4. Click **"Create project"**
5. Note down the project name

---

### 1. Clone and Configure

Now you have your Cloudflare credentials, run the setup script:

```bash
git clone https://github.com/parasquid/wp-hugo-static.git
cd wp-hugo-static
./setup.sh
```

The setup script will prompt for:
- **Public domain** - Your Hugo site domain (e.g., `blog.yourdomain.com`)
- **Private domain** - WordPress domain via Tailscale (e.g., `wordpress.your-tailnet.ts.net`)
- **Cloudflare API Token** - From step 2 above
- **Cloudflare Account ID** - From step 1 above
- **Cloudflare Pages Project** - From step 3 above
- GitHub repository and token
- Site title and author info
- Giscus configuration

### 2. Start WordPress

```bash
docker compose up -d wordpress db builder
```

Access WordPress at **http://localhost:8888**

### 3. Configure GitHub Secrets for Deployment

GitHub Actions needs the same Cloudflare credentials you entered in setup.sh to deploy your site:

Go to your repository → **Settings** → **Secrets and variables** → **Actions**

Add the following secrets:
- `CLOUDFLARE_API_TOKEN` - Your Cloudflare API token from the Prerequisites section
- `CLOUDFLARE_ACCOUNT_ID` - Your Cloudflare account ID
- `CLOUDFLARE_PAGES_PROJECT` - Your Pages project name
- `WP_API_URL` - Your WordPress REST API URL (e.g., `http://wordpress/wp-json/wp/v2`)
- `GITHUB_TOKEN` - GitHub Personal Access Token (create at https://github.com/settings/tokens)

### 4. Deploy

```bash
# Trigger a build
gh workflow run deploy.yml

# Or push to main branch
git push origin main
```

### 5. Set Up Giscus

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

| Variable | Description | How to Get |
|----------|-------------|------------|
| `PUBLIC_DOMAIN` | Your public Hugo site domain | Your domain or `yoursite.pages.dev` |
| `WP_HOST` | Private WordPress domain (Tailscale) | Your Tailscale Magic DNS name |
| `CLOUDFLARE_API_TOKEN` | Cloudflare API token | [Create here](https://dash.cloudflare.com/profile/api-tokens) |
| `CLOUDFLARE_ACCOUNT_ID` | Cloudflare account ID | Right sidebar in Cloudflare dashboard |
| `CLOUDFLARE_PAGES_PROJECT` | Pages project name | Created in Cloudflare Pages |
| `DB_PASSWORD` | WordPress database password | Auto-generated by setup.sh |
| `GITHUB_TOKEN` | GitHub PAT for webhooks | [Create here](https://github.com/settings/tokens) |
| `GISCUS_REPO` | GitHub repo for comments | Your repo (e.g., `owner/repo`) |

### Hybrid Content

wp-hugo-static supports three content types:

1. **WordPress Posts** - Blog content, imported automatically
2. **WordPress Pages** - Static pages, imported automatically
3. **Custom Hugo Pages** - Hand-coded pages with custom layouts

See `docs/hybrid-content.md` for details.

### Baked Comments and Archive Workflow

wp-hugo-static includes a baked comments feature that fetches comments at build time and embeds them directly into the static HTML.

#### How Baked Comments Work

1. During the Hugo build process, comments are fetched from the WordPress REST API
2. Comments are rendered as static HTML and embedded in the page
3. This means comments are visible in the page source, improving SEO
4. Search engines can index comment content, which wouldn't be possible with client-side loaded comments

#### Active Posts vs Archived Posts

- **Active Posts**: Display the Giscus widget for real-time comment interaction via GitHub Discussions
- **Archived Posts**: Display only the baked (static) comments with no Giscus widget. This makes archived posts read-only.

#### How to Archive a Post

To archive a post in WordPress:

1. Open the post in the WordPress admin panel
2. Add the category "Archived" to the post
3. Save/update the post
4. Trigger a new build (push to main or run the deploy workflow)

The build script automatically detects posts with the "Archived" category and:
- Includes the baked comments in the static output
- Removes the Giscus widget to make the post read-only

This workflow is ideal for older posts that you want to preserve for reference but no longer want to accept new comments on.

## Testing

wp-hugo-static includes several seed scripts to help you test the full workflow without manually creating content.

### Available Test Scripts

| Script | Description |
|--------|-------------|
| `scripts/ensure-archived-category.rb` | Ensures the "Archived" category exists in WordPress |
| `scripts/seed-posts.rb` | Creates test posts in WordPress with various categories |
| `scripts/seed-discussions.rb` | Creates sample GitHub Discussions for testing baked comments |

### Running the Test Scripts

**Prerequisites:**
- Docker and Docker Compose (must be running)
- Ruby 3.4+ (or use the included Ruby container)

First, ensure Ruby dependencies are installed:

```bash
cd scripts
bundle install
```

### Running Test Scripts

All scripts run via Docker. See [docs/testing.md](docs/testing.md) for:
- First-time setup (installing Podman, starting services)
- Full testing workflow
- Verification steps

Quick start:

```bash
# Start the builder container
docker compose up -d wordpress db builder
docker compose exec -e WP_API_URL=http://wordpress/wp-json/wp/v2 \
  -e WP_USERNAME=admin -e WP_APPLICATION_PASSWORD=xxx \
  builder ruby scripts/ensure-archived-category.rb
docker compose exec -e WP_API_URL=http://wordpress/wp-json/wp/v2 \
  -e WP_USERNAME=admin -e WP_APPLICATION_PASSWORD=xxx \
  builder ruby scripts/seed-posts.rb
GITHUB_TOKEN=xxx GITHUB_REPO=owner/repo \
  docker compose exec -e WP_API_URL=http://wordpress/wp-json/wp/v2 \
  builder ruby scripts/seed-discussions.rb
```

### Testing Workflow

Follow this sequence to test the complete pipeline:

```bash
# 1. Reset: Clear existing content from Hugo
rm -rf hugo-site/content/posts/*
rm -rf hugo-site/content/pages/*

# 2. Seed: Create test content in WordPress
docker compose exec -e WP_API_URL=http://wordpress/wp-json/wp/v2 \
  -e WP_USERNAME=admin -e WP_APPLICATION_PASSWORD=xxx \
  builder ruby scripts/ensure-archived-category.rb
docker compose exec -e WP_API_URL=http://wordpress/wp-json/wp/v2 \
  -e WP_USERNAME=admin -e WP_APPLICATION_PASSWORD=xxx \
  builder ruby scripts/seed-posts.rb
GITHUB_TOKEN=xxx GITHUB_REPO=owner/repo \
  docker compose exec -e WP_API_URL=http://wordpress/wp-json/wp/v2 \
  builder ruby scripts/seed-discussions.rb

# 3. Fetch: Import content from WordPress to Hugo
docker compose exec -e WP_API_URL=http://wordpress/wp-json/wp/v2 \
  -e WP_USERNAME=admin -e WP_APPLICATION_PASSWORD=xxx \
  builder ruby scripts/fetch-posts.rb
docker compose exec -e WP_API_URL=http://wordpress/wp-json/wp/v2 \
  -e WP_USERNAME=admin -e WP_APPLICATION_PASSWORD=xxx \
  builder ruby scripts/fetch-pages.rb

# 4. Build: Generate the static site
docker compose exec builder hugo -s /app/hugo-site

# 5. Verify: Check the output
# - Open hugo-site/public in a browser
# - Check that baked comments appear on archived posts
# - Check that Giscus widget appears on active posts
```

This workflow tests the complete cycle from content creation in WordPress to static generation in Hugo, including the baked comments and archive functionality.

## File Structure

```
wp-hugo-static/
├── docker-compose.yml      # Docker services
├── Dockerfile.builder      # Builder container with Ruby, Hugo, Go
├── .env.example           # Environment template
├── setup.sh               # Setup script
├── hugo-site/             # Hugo static site
│   ├── hugo.toml          # Hugo configuration
│   ├── go.mod             # Hugo Modules
│   ├── content/           # Markdown content
│   ├── layouts/           # Custom layouts
│   └── static/            # Static files
├── scripts/               # Scripts
│   ├── fetch-posts.rb     # WP posts → Hugo
│   ├── fetch-pages.rb     # WP pages → Hugo
│   ├── fetch-images.rb    # Download images
│   ├── backup.sh          # Backup script
│   ├── restore.sh         # Restore script
│   ├── seed-wordpress.sh  # Seed WordPress with test content
│   └── Gemfile            # Ruby dependencies
├── .github/workflows/     # GitHub Actions
│   └── deploy.yml         # CI/CD pipeline
└── docs/                  # Documentation
    └── hybrid-content.md  # Content strategy
```

## Backup and Restore

Backup and restore scripts are in `scripts/` folder:

### Backup

```bash
./scripts/backup.sh
```

Or with custom settings:

```bash
BACKUP_DIR=./backups RETENTION_DAYS=7 ./scripts/backup.sh
```

Backs up:
- WordPress database
- Full WordPress files (uploads, plugins, themes)

Note: Backup runs manually or via cron. WUD does not run backups automatically.

### Restore

```bash
./scripts/restore.sh db_20240101_023000.sql.gz wp-content_20240101_023000.tar.gz
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

### Image Optimization

wp-hugo-static automatically resizes, watermarks, and converts images to WebP/AVIF. See [docs/image-optimization.md](docs/image-optimization.md) for customization options.

## Contributing

Contributions are welcome! Please read [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

This project follows the [Ruby Community Code of Conduct](CODE_OF_CONDUCT.md).

## License

GNU Affero General Public License v3.0 (AGPLv3) - see [LICENSE](LICENSE) for details.

This means:
- You can use, modify, and distribute this software
- If you modify and deploy it over a network, you must provide source code to users
- All derivative works must also be licensed under AGPLv3