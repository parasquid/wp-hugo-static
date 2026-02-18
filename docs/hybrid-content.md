# Hybrid Content Strategy

This project supports three types of content, allowing you to choose the best approach for each use case:

## 1. WordPress Posts (Blog Content)

**Best for**: Regular blog posts, news articles, time-sensitive content

**How it works**:
- Write in WordPress admin
- Automatically imported by `scripts/fetch-posts.rb`
- Converted to Hugo markdown during CI/CD build
- Triggered by webhook on publish

**Location after import**: `hugo-site/content/posts/`

## 2. WordPress Pages (Static Content)

**Best for**: About pages, contact info, standard website pages

**How it works**:
- Write in WordPress admin (Pages section)
- Automatically imported by `scripts/fetch-pages.rb`
- Same build process as posts

**Location after import**: `hugo-site/content/pages/`

## 3. Custom Hugo Pages (Complex Designs)

**Best for**: Landing pages, special layouts, highly customized designs

**How it works**:
- Write directly in `hugo-site/content/custom/`
- Create custom layouts in `hugo-site/layouts/`
- Not managed by WordPress
- Version controlled in Git

**Location**: `hugo-site/content/custom/`

## Template Hierarchy

Hugo uses the following lookup order:

1. `layouts/{type}/single.html` - Custom layout for specific content type
2. `layouts/_default/single.html` - Default layout
3. Theme's layouts

## Example: Creating a Custom Landing Page

1. Create content file:
   ```bash
   hugo new content/custom/my-landing.md
   ```

2. Add frontmatter with custom type:
   ```yaml
   ---
   title: 'My Landing Page'
   type: 'custom-landing'
   ---
   ```

3. Create custom layout:
   ```bash
   mkdir -p hugo-site/layouts/custom-landing
   touch hugo-site/layouts/custom-landing/single.html
   ```

4. Design your custom HTML/CSS in the layout file

## Choosing the Right Approach

| Use Case | Recommendation |
|----------|----------------|
| Blog posts | WordPress Posts |
| About/Contact pages | WordPress Pages |
| Landing pages | Custom Hugo Pages |
| Documentation | Custom Hugo Pages |
| Team bios | WordPress Pages |
| Special campaigns | Custom Hugo Pages |

## Important Notes

- Custom Hugo pages are NOT overwritten by WordPress imports
- You can override imported content by creating a file with the same slug in `content/custom/`
- Images referenced in custom pages should be placed in `hugo-site/static/images/`
