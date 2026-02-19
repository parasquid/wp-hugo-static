# Contributing to wp-hugo-static

Thank you for your interest in contributing to wp-hugo-static! This document provides guidelines and instructions for contributing.

## Code of Conduct

By participating in this project, you agree to abide by our [Code of Conduct](CODE_OF_CONDUCT.md). Please read it before contributing.

## How to Contribute

### Reporting Issues

1. Check if the issue has already been reported
2. Use the issue template if available
3. Provide clear steps to reproduce
4. Include relevant environment details (OS, Docker version, Hugo version, etc.)

### Submitting Changes

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/my-feature`)
3. Make your changes
4. Test your changes locally:
   - Run `docker compose up -d --build` to test infrastructure changes
   - Run `hugo server -D` in `hugo-site/` to test Hugo changes
   - Run Ruby scripts manually to test content pipeline changes
5. Commit your changes with a clear commit message
6. Push to your fork
7. Open a Pull Request

### Development Setup

See [README.md](README.md) for setup instructions.

### Code Style

- **Ruby**: Follow the [Ruby Style Guide](https://rubystyle.guide/)
- **Shell scripts**: Use shellcheck for validation
- **Docker**: Keep images pinned to specific versions
- **Hugo**: Use Hugo Modules, not git submodules

### Project Structure

```
wp-hugo-static/
├── docker-compose.yml    # Docker services (changes need testing)
├── Dockerfile.caddy      # Custom Caddy build
├── Caddyfile             # Caddy configuration
├── scripts/              # Ruby conversion scripts
├── hugo-site/            # Hugo static site
└── .github/workflows/    # CI/CD pipeline
```

### What We're Looking For

- Bug fixes
- Documentation improvements
- Performance optimizations
- Additional test coverage
- Security improvements

### What We're NOT Looking For

- Site-specific customizations (these belong in your own fork)
- Changes that break backward compatibility without discussion
- Features that significantly increase maintenance burden

## Questions?

Open an issue with the "question" label, and we'll help you out.

## License

By contributing, you agree that your contributions will be licensed under the GNU Affero General Public License v3.0 (AGPLv3). See [LICENSE](LICENSE) for details.
