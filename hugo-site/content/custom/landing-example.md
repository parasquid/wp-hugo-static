---
title: 'Custom Landing Page'
date: 2024-01-01T00:00:00Z
draft: false
type: 'custom-landing'
---

This is a custom landing page that uses a unique Hugo template.

Unlike pages from WordPress (which use the default template), this page has its own custom layout defined in `layouts/custom-landing/single.html`.

## Hybrid Content Strategy

You have three options for content:

1. **WordPress Posts** → Imported automatically via `fetch-posts.rb`
2. **WordPress Pages** → Imported automatically via `fetch-pages.rb`
3. **Custom Hugo Pages** → Written directly in `content/custom/` with custom layouts

This flexibility allows you to:
- Use WordPress for blog content (easy editing)
- Use Hugo for complex landing pages (custom design)
- Mix both approaches as needed
