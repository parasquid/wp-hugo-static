# Image Optimization

wp-hugo-static automatically optimizes images during the fetch process. This document explains how the pipeline works, what formats are generated, and how to customize settings.

## How Image Processing Works

The image processing pipeline runs automatically when you execute `scripts/fetch-images.rb`. Each image goes through several stages:

1. **Download** - Images are fetched from WordPress and saved to `hugo-site/static/images/`
2. **Resize** - Landscape images wider than 1920px get scaled down. Portrait images taller than 1200px get scaled down. Smaller images pass through unchanged.
3. **Watermark** - A tiled watermark pattern gets applied to every image. This protects your content from unauthorized copying.
4. **Convert** - Two modern formats get generated: WebP and AVIF. These offer superior compression compared to JPEG or PNG.
5. **Optimize** - Additional lossless optimizations run on all variants to strip unnecessary metadata and reduce file size.

The script processes both content images (embedded in post body) and featured images (post thumbnails).

## Generated Formats

For each source image, the pipeline produces three versions:

| Format | Quality | Use Case |
|--------|---------|----------|
| Original (PNG/JPG) | 100% | Fallback for older browsers |
| WebP | 80% | Modern browsers, good compression |
| AVIF | 50% | Best compression, newest browsers |

AVIF offers the best compression but lacks support in older browsers. WebP provides excellent compatibility with reasonable file sizes. The original format serves as a fallback for visitors using browsers that don't support either modern format.

Hugo's image processing partials detect browser support automatically and serve the smallest supported format.

## Customizing the Watermark

The watermark consists of your site URL tiled across the image.

### Automatic Generation

`setup.sh` automatically generates the watermark at `hugo-site/static/images/watermark.png` using your `PUBLIC_DOMAIN`.

### Regenerate the Watermark

To regenerate the watermark:

```bash
docker compose run --rm -e SITE_URL=your-domain.com -w /app/scripts builder ruby generate-watermark.rb
```

### Manual Customization

The setup.sh generates a default watermark with your domain. You can customize it later by either:

1. **Regenerate** - run the script with a different URL:
   ```bash
   docker compose run --rm -e SITE_URL=your-domain.com -w /app/scripts builder ruby generate-watermark.rb
   ```

2. **Replace** - create your own `watermark.png` at `hugo-site/static/images/watermark.png`:

- Square aspect ratio works best (100x100 pixels recommended)
- Should contain your site name, logo, or copyright text
- Keep it simple. Complex watermarks create visual noise.

The script applies this watermark in a tiled pattern across each image at 20% opacity.

### Watermark Configuration

Edit constants at the top of `scripts/fetch-images.rb` to adjust:

```ruby
WATERMARK_SIZE = 100       # Pixel size of watermark tile
WATERMARK_OPACITY = 0.20   # Transparency (0.0 to 1.0)
WATERMARK_TILES = 4         # Grid size (4x4 = 16 tiles per image)
WATERMARK_JITTER = 20       # Random offset in pixels
```

Increasing `WATERMARK_JITTER` adds randomization to watermark placement, making removal attacks harder.

## Performance and Build Times

First run processes every image from scratch. Expect longer build times depending on:

- Number of posts with images
- Total image file size
- Server resources available

Subsequent runs stay fast. The script checks modification times and skips images that already have WebP and AVIF variants newer than the original. This makes incremental updates nearly instant.

To force reprocessing all images, delete the processed variants:

```bash
rm hugo-site/static/images/content/*/*.webp
rm hugo-site/static/images/content/*/*.avif
rm hugo-site/static/images/featured/*.{webp,avif}
```

Then run the fetch script again.

## Troubleshooting

### "convert: command not found"

ImageMagick isn't installed in the builder container. Rebuild the container:

```bash
docker compose build builder
docker compose up -d builder
```

### Watermark not visible

Two common causes exist. First, verify `watermark.png` exists in the static images directory. The script outputs "Applying tiled watermark" only when it finds this file. Second, check that the watermark file has actual content. A completely white PNG won't render visibly transparent or.

### WebP/AVIF not served

Hugo needs image processing partials that detect browser support. Ensure your theme or layouts include proper format detection. The Stack theme includes this functionality out of the box.

If using a custom theme, add picture element markup that tests for AVIF, then WebP, then falls back to original format.

### Out of memory during processing

Large images consume significant memory during conversion. Reduce `MAX_LANDSCAPE_WIDTH` and `MAX_PORTRAIT_HEIGHT` in the script to process smaller versions instead.
