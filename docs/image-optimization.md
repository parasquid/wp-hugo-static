# Image Optimization

wp-hugo-static automatically optimizes images during the fetch process. This document explains how the pipeline works, what formats are generated, and how to customize settings.

## How Image Processing Works

The image processing pipeline runs automatically when you execute `scripts/fetch-images.rb`. Each image goes through these stages:

1. **Download** - Images are fetched from WordPress and saved to `hugo-site/static/images/`
2. **Resize** - Landscape images wider than 1920px get scaled down. Portrait images taller than 1200px get scaled down. Smaller images pass through unchanged.
3. **Watermark** - A tiled watermark pattern gets applied to every image. This protects your content from unauthorized copying.
4. **Convert** - Images are converted to WebP (`WEBP_QUALITY=80`).
5. **Optimize** - `image_optim` runs on generated WebP files.

Current behavior details from implementation:
- For non-SVG/non-animated images, the original downloaded file is deleted after successful WebP conversion.
- SVG and animated GIF files are skipped from conversion and kept as original files.

The script processes both content images (embedded in post body) and featured images (post thumbnails).

## Generated Formats

For standard raster content images, the pipeline currently produces one optimized format:

| Format | Quality | Use Case |
|--------|---------|----------|
| WebP | 80% | Primary delivery format |

Exceptions:
- SVG files are preserved as SVG.
- Animated GIF files are preserved as GIF.

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

The current script behavior uses:
- Tile grid: 4x4
- Opacity: 20% dissolve
- Rotation jitter: random between -30 and +30 degrees
- Position jitter: random between -20 and +20 pixels

To change these values, update `apply_tiled_watermark` in `scripts/fetch-images.rb`.

## Performance and Build Times

First run processes every image from scratch. Expect longer build times depending on:

- Number of posts with images
- Total image file size
- Server resources available

Subsequent runs stay fast. The script checks modification times and skips images that already have WebP output newer than the original source file.

To force reprocessing all images, delete the processed variants:

```bash
rm -f hugo-site/static/images/content/*/*.webp
rm -f hugo-site/static/images/featured/*.webp
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

### WebP not served

Ensure generated markdown paths were updated to `/images/.../*.webp` and that files exist under `hugo-site/static/images/`.

### Out of memory during processing

Large images consume significant memory during conversion. Reduce `MAX_LANDSCAPE_WIDTH` and `MAX_PORTRAIT_HEIGHT` in the script to process smaller versions instead.
