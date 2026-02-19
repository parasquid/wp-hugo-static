# Image Optimization + Watermarking for WordPress→Hugo Pipeline

## TL;DR

> **Goal**: Add image optimization and watermarking to reduce Cloudflare Pages bandwidth costs
>
> **Deliverables**:
> - Modified `fetch-images.rb` with resize, watermark, WebP conversion
> - Default watermark.png generator
> - Hugo `<picture>` template for format fallbacks
> - Updated Dockerfile.builder and GitHub Actions
>
> **Estimated Effort**: Medium (~2-3 hours implementation)
> **Parallel Execution**: NO - sequential dependencies
> **Critical Path**: Dockerfile changes → Gemfile updates → Script modifications → Template updates

---

## Context

### Original Request
User wants to optimize images during the WordPress→Hugo pipeline to reduce Cloudflare Pages storage and bandwidth:
- Resize to max 1920px width
- Apply tiled watermark with slight jitter
- Generate WebP variants (WebP only, no original fallback)
- Watermark FIRST, then optimize

### Key Decisions Made
- **Max resolution**: 1920px width (landscape), 1200px height (portrait)
- **Watermark pattern**: Tiled grid with jitter (Option B)
- **Formats**: WebP only (no original, no AVIF)
- **Quality**: WebP 80%
- **Watermark file**: `hugo-site/static/images/watermark.png`
- **Default watermark**: Site URL from Hugo config (e.g., "example.com")

### Metis Review Findings
**Critical gaps identified and addressed in this plan**:
1. ✅ **ImageMagick dependency**: Will add to Dockerfile and GitHub Actions
2. ✅ **Format exclusions**: SVG and animated images will be skipped
3. ✅ **Hugo template integration**: Will create custom image partial
4. ✅ **Idempotency**: Will implement checksum-based caching
5. ✅ **Build performance**: Will skip unchanged images

---

## Work Objectives

### Core Objective
Modify the image fetch pipeline to watermark, resize, and generate modern format variants (WebP/AVIF) while maintaining backward compatibility with fallback images.

### Concrete Deliverables
1. Updated `Dockerfile.builder` with ImageMagick and optimization tools
2. Updated `.github/workflows/deploy.yml` with image dependencies
3. Modified `scripts/fetch-images.rb` with processing pipeline
4. New `scripts/generate-watermark.rb` for default watermark creation (using site URL)
5. Updated `scripts/Gemfile` with mini_magick and image_optim
6. Hugo template updates for WebP images
7. Documentation for usage

### Definition of Done
- [ ] All images from WordPress are watermarked, resized, and converted to WebP
- [ ] GitHub Actions builds successfully
- [ ] SVG and animated images are preserved unchanged

### Must Have
- ImageMagick installed in both Docker and CI environments
- Watermark applied to all processed images (using site URL)
- WebP variants generated (originals deleted after conversion)
- Max dimensions enforced (1920px/1200px)
- SVG/GIF excluded from processing

### Must NOT Have (Guardrails)
- Video processing
- AI/smart cropping
- Dynamic per-post watermarks
- External CDN integration (Cloudflare Images, etc.)
- Multiple responsive sizes (only max + original)

---

## Verification Strategy

### Test Decision
- **Infrastructure exists**: YES (Ruby scripts already tested in CI)
- **Automated tests**: NO (manual verification via QA scenarios)
- **Framework**: None - verification via agent-executed scenarios
- **Agent QA**: YES - every task includes verification steps

### QA Policy
Every task MUST include agent-executed QA scenarios. Evidence saved to `.sisyphus/evidence/task-{N}-{scenario-slug}.{ext}`.

**Verification methods**:
- **Build verification**: Run fetch-images.rb, check output files exist
- **Image inspection**: Open processed images to verify watermark
- **Format check**: Verify WebP/AVIF files exist and are smaller than original
- **Template check**: Build Hugo, inspect HTML for `<picture>` element
- **CI verification**: Trigger GitHub Actions, verify green build

---

## Execution Strategy

### Sequential Execution (Dependencies Required)

```
Wave 1 (Infrastructure - MUST complete before Wave 2):
├── Task 1: Add ImageMagick to Dockerfile.builder
├── Task 2: Update GitHub Actions workflow
└── Task 3: Add Ruby gems (mini_magick, image_optim)

Wave 2 (Core Implementation - depends on Wave 1):
├── Task 4: Create watermark generator script
├── Task 5: Implement image processing pipeline in fetch-images.rb
└── Task 6: Add format exclusions (SVG, GIF) and caching logic

Wave 3 (Hugo Integration - depends on Wave 2):
├── Task 7: Create Hugo image partial with <picture> element
└── Task 8: Test end-to-end workflow locally

Wave 4 (Verification):
├── Task 9: GitHub Actions CI verification
└── Task 10: Create documentation

Critical Path: Task 1 → Task 2 → Task 3 → Task 5 → Task 7 → Task 9
```

### Agent Dispatch Summary

- **Wave 1**: All 3 tasks → `quick` (package installations, config updates)
- **Wave 2**: Task 4 → `quick`, Task 5 → `unspecified-high` (complex Ruby logic), Task 6 → `quick`
- **Wave 3**: Task 7 → `unspecified-high` (Hugo template work), Task 8 → `unspecified-high` (integration testing)
- **Wave 4**: Task 9 → `quick`, Task 10 → `writing`

---

## TODOs

- [x] 1. Add ImageMagick and image tools to Dockerfile.builder

  **What to do**:
  - Add ImageMagick and related packages to Dockerfile.builder
  - Install: imagemagick, libmagickwand-dev, webp, libavif-bin, jpegoptim, optipng, pngquant
  - Test that `convert --version` works in the container

  **Must NOT do**:
  - Don't install unnecessary GUI tools
  - Don't change Ruby or Hugo versions

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: None needed
  - **Reason**: Simple package installation in Dockerfile

  **Parallelization**:
  - **Can Run In Parallel**: YES (Wave 1)
  - **Parallel Group**: Wave 1 (with Tasks 2, 3)
  - **Blocks**: Task 5 (needs ImageMagick)
  - **Blocked By**: None

  **References**:
  - Current Dockerfile: `Dockerfile.builder` (lines 26-59 show current apt-get pattern)
  - Required packages: imagemick, libmagickwand-dev, webp, libavif-bin, jpegoptim, optipng, pngquant

  **Acceptance Criteria**:
  - [ ] Dockerfile.builder includes all image processing packages
  - [ ] Build succeeds: `docker build -f Dockerfile.builder -t test-builder .`
  - [ ] ImageMagick available: `docker run test-builder convert --version` shows version
  - [ ] WebP tools available: `docker run test-builder cwebp -version` works

  **QA Scenarios**:
  ```
  Scenario: Verify ImageMagick installation
    Tool: Bash
    Preconditions: Dockerfile.builder modified
    Steps:
      1. Run: docker build -f Dockerfile.builder -t test-builder .
      2. Run: docker run --rm test-builder convert --version
    Expected Result: ImageMagick version output displayed (e.g., "Version: ImageMagick 6.9.x")
    Failure Indicators: "convert: command not found" or build errors
    Evidence: .sisyphus/evidence/task-1-imagemagick-version.txt

  Scenario: Verify WebP tools
    Tool: Bash
    Preconditions: Docker image built
    Steps:
      1. Run: docker run --rm test-builder cwebp -version
    Expected Result: WebP version displayed (e.g., "cwebp 1.x.x")
    Failure Indicators: "cwebp: command not found"
    Evidence: .sisyphus/evidence/task-1-webp-version.txt
  ```

  **Evidence to Capture**:
  - [ ] task-1-imagemagick-version.txt
  - [ ] task-1-webp-version.txt
  - [ ] Screenshot of successful docker build (if terminal output)

  **Commit**: YES
  - Message: `chore(docker): add ImageMagick and image optimization tools`
  - Files: `Dockerfile.builder`
  - Pre-commit: `docker build -f Dockerfile.builder -t test-builder .`

- [x] 2. Update GitHub Actions workflow with image dependencies

  **What to do**:
  - Add step to install ImageMagick and image tools in `.github/workflows/deploy.yml`
  - Install same packages as Dockerfile: imagemagick, libmagickwand-dev, webp, libavif-bin, jpegoptim, optipng, pngquant
  - Place BEFORE the "Setup Ruby" step

  **Must NOT do**:
  - Don't modify existing Ruby/Hugo setup steps
  - Don't change deployment configuration

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: None needed
  - **Reason**: Simple workflow modification

  **Parallelization**:
  - **Can Run In Parallel**: YES (Wave 1)
  - **Parallel Group**: Wave 1 (with Tasks 1, 3)
  - **Blocks**: Task 9 (CI verification)
  - **Blocked By**: None

  **References**:
  - Current workflow: `.github/workflows/deploy.yml` (lines 1-75)
  - Pattern: Use `sudo apt-get install` in workflow step

  **Acceptance Criteria**:
  - [ ] New step added to deploy.yml before Ruby setup
  - [ ] All required packages listed in apt-get install
  - [ ] Workflow syntax is valid YAML

  **QA Scenarios**:
  ```
  Scenario: Validate workflow syntax
    Tool: Bash
    Preconditions: deploy.yml modified
    Steps:
      1. Run: cat .github/workflows/deploy.yml | head -40
      2. Verify new step exists with apt-get install
    Expected Result: YAML contains new step with imagemagick, webp, etc.
    Failure Indicators: Syntax errors, missing step
    Evidence: .sisyphus/evidence/task-2-workflow-yaml.txt

  Scenario: Verify workflow triggers
    Tool: Web (GitHub)
    Preconditions: Changes pushed to branch
    Steps:
      1. Push to branch
      2. Open GitHub Actions tab
      3. Check if workflow can be triggered manually
    Expected Result: Workflow file recognized by GitHub
    Failure Indicators: GitHub reports workflow errors
    Evidence: .sisyphus/evidence/task-2-github-workflow.png
  ```

  **Evidence to Capture**:
  - [ ] task-2-workflow-yaml.txt
  - [ ] task-2-github-workflow.png

  **Commit**: YES
  - Message: `ci(github): add image processing dependencies to workflow`
  - Files: `.github/workflows/deploy.yml`
  - Pre-commit: Validate YAML syntax

- [x] 3. Add Ruby gems for image processing

  **What to do**:
  - Add `mini_magick` and `image_optim` gems to `scripts/Gemfile`
  - Run `bundle install` to update Gemfile.lock
  - Verify gems are loadable

  **Must NOT do**:
  - Don't add unnecessary gem dependencies
  - Don't change existing gem versions

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: None needed
  - **Reason**: Gemfile modification

  **Parallelization**:
  - **Can Run In Parallel**: YES (Wave 1)
  - **Parallel Group**: Wave 1 (with Tasks 1, 2)
  - **Blocks**: Task 5 (needs gems)
  - **Blocked By**: None

  **References**:
  - Current Gemfile: `scripts/Gemfile`
  - Gems to add: mini_magick (~> 4.12), image_optim (~> 0.31)

  **Acceptance Criteria**:
  - [ ] mini_magick added to Gemfile
  - [ ] image_optim added to Gemfile
  - [ ] Bundle install completes successfully
  - [ ] Can require gems in Ruby: `ruby -r mini_magick -e 'puts MiniMagick.version'`

  **QA Scenarios**:
  ```
  Scenario: Verify gem installation
    Tool: Bash
    Preconditions: Gemfile modified
    Steps:
      1. Run: cd scripts && bundle install
      2. Run: ruby -r mini_magick -e 'puts MiniMagick.version'
    Expected Result: MiniMagick version number printed
    Failure Indicators: Gem not found, load errors
    Evidence: .sisyphus/evidence/task-3-gem-version.txt
  ```

  **Evidence to Capture**:
  - [ ] task-3-gem-version.txt

  **Commit**: YES
  - Message: `chore(deps): add mini_magick and image_optim gems`
  - Files: `scripts/Gemfile`, `scripts/Gemfile.lock`
  - Pre-commit: `bundle install` completes

- [x] 4. Create watermark generator script

  **What to do**:
  - Create `scripts/generate-watermark.rb` that generates a default watermark.png
  - Use ImageMagick to create text-based watermark with site URL
  - Text: Use site URL from environment or default to "example.com"
  - Style: Semi-transparent, subtle gray text
  - Output: `hugo-site/static/images/watermark.png`
  - Script should be idempotent (overwrite if exists)

  **Must NOT do**:
  - Don't use external image files as base
  - Don't make watermark too prominent (keep it subtle)
  - Don't require manual steps to generate

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: None needed
  - **Reason**: Standalone script, straightforward ImageMagick usage

  **Parallelization**:
  - **Can Run In Parallel**: YES (Wave 2)
  - **Parallel Group**: Wave 2 (with Tasks 5, 6)
  - **Blocks**: Task 5 (needs watermark.png)
  - **Blocked By**: Task 1 (needs ImageMagick), Task 3 (needs mini_magick)

  **References**:
  - ImageMagick text generation: `convert -background transparent -fill gray50 -gravity center -pointsize 48 label:"TEXT" watermark.png`
  - Current scripts pattern: `scripts/fetch-posts.rb` for Ruby structure
  - Output location: `hugo-site/static/images/watermark.png`

  **Acceptance Criteria**:
  - [ ] Script created at `scripts/generate-watermark.rb`
  - [ ] Generates `hugo-site/static/images/watermark.png`
  - [ ] Watermark is semi-transparent PNG
  - [ ] Script is executable and idempotent

  **QA Scenarios**:
  ```
  Scenario: Generate watermark
    Tool: Bash
    Preconditions: ImageMagick installed
    Steps:
      1. Run: cd scripts && ruby generate-watermark.rb
      2. Run: ls -la ../hugo-site/static/images/watermark.png
    Expected Result: watermark.png created (approx 150x150px, semi-transparent)
    Failure Indicators: File not created, error output
    Evidence: .sisyphus/evidence/task-4-watermark-generated.png

  Scenario: Verify watermark properties
    Tool: Bash
    Preconditions: watermark.png exists
    Steps:
      1. Run: identify -verbose hugo-site/static/images/watermark.png | grep -E "(Print size|Resolution|Colorspace)"
    Expected Result: Shows PNG format, transparent background, reasonable size (100-200px)
    Failure Indicators: Wrong format, no transparency, wrong dimensions
    Evidence: .sisyphus/evidence/task-4-watermark-properties.txt
  ```

  **Evidence to Capture**:
  - [ ] task-4-watermark-generated.png
  - [ ] task-4-watermark-properties.txt

  **Commit**: YES
  - Message: `feat(scripts): add watermark generator script`
  - Files: `scripts/generate-watermark.rb`, `hugo-site/static/images/watermark.png`
  - Pre-commit: `ruby scripts/generate-watermark.rb` succeeds

- [x] 5. Implement image processing pipeline in fetch-images.rb

  **What to do**:
  - Modify `scripts/fetch-images.rb` to process images after download
  - Processing pipeline per image:
    1. Resize to max 1920px width (maintain aspect ratio)
    2. Apply tiled watermark with jitter
    3. Save watermarked original (overwrites downloaded file)
    4. Convert to WebP (quality 80%)
    5. Convert to AVIF (quality 50%)
    6. Run image_optim on all variants
  - Update content image references to use .webp extension
  - Keep original extension for featured images

  **Watermark Implementation**:
  - Use mini_magick for all operations
  - Create tiled overlay with jittered positions
  - Grid: 4x4 base with ±20px random offset per tile
  - Opacity: 20% (very subtle)
  - Watermark size: 100x100px

  **Must NOT do**:
  - Don't process SVG or animated GIF files
  - Don't change image URLs in markdown content yet
  - Don't delete original files until variants are confirmed

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
  - **Skills**: None needed
  - **Reason**: Complex Ruby logic with ImageMagick operations, requires careful testing

  **Parallelization**:
  - **Can Run In Parallel**: NO (Wave 2 sequential)
  - **Parallel Group**: Wave 2
  - **Blocks**: Task 7 (Hugo templates need processed images)
  - **Blocked By**: Task 1 (ImageMagick), Task 3 (gems), Task 4 (watermark.png)

  **References**:
  - Current script: `scripts/fetch-images.rb` (full file, lines 1-125)
  - MiniMagick docs: Composite operations, resize, convert
  - ImageMagick tiling: Use composite with multiple positions
  - WebP conversion: `cwebp -q 80 input.jpg -output.webp`
  - AVIF conversion: `avifenc --min 0 --max 63 -a end-usage=q -a cq-level=32 input.jpg output.avif`

  **Acceptance Criteria**:
  - [ ] fetch-images.rb resizes images to max 1920px
  - [ ] Watermark applied to all processed images
  - [ ] WebP variant created for each image
  - [ ] AVIF variant created for each image
  - [ ] All variants are smaller than original (for photos)
  - [ ] Script completes without errors on test images

  **QA Scenarios**:
  ```
  Scenario: Process a test image
    Tool: Bash
    Preconditions: WordPress running with test images, watermark.png exists
    Steps:
      1. Run: cd scripts && ruby fetch-images.rb
      2. Check: ls hugo-site/static/images/content/test-post/
    Expected Result: Contains original.jpg, original.webp, original.avif
    Failure Indicators: Missing variants, errors in output
    Evidence: .sisyphus/evidence/task-5-processed-files.txt

  Scenario: Verify watermark applied
    Tool: Bash (ImageMagick)
    Preconditions: Processed images exist
    Steps:
      1. Compare original download vs processed: compare original.jpg processed.jpg -metric AE diff.png
      2. Or visually inspect processed image
    Expected Result: Images clearly show tiled watermark pattern
    Failure Indicators: No visible difference (watermark not applied)
    Evidence: .sisyphus/evidence/task-5-watermark-comparison.png

  Scenario: Verify size reduction
    Tool: Bash
    Preconditions: WebP and AVIF files exist
    Steps:
      1. Run: du -b hugo-site/static/images/content/test-post/*
    Expected Result: WebP and AVIF smaller than original (for photos >50KB)
    Failure Indicators: WebP/AVIF same size or larger
    Evidence: .sisyphus/evidence/task-5-file-sizes.txt
  ```

  **Evidence to Capture**:
  - [ ] task-5-processed-files.txt
  - [ ] task-5-watermark-comparison.png
  - [ ] task-5-file-sizes.txt
  - [ ] Example processed images

  **Commit**: YES
  - Message: `feat(scripts): add image processing with watermark and modern formats`
  - Files: `scripts/fetch-images.rb`
  - Pre-commit: Script runs without errors

- [x] 6. Add format exclusions and caching logic

  **What to do**:
  - Add logic to skip processing for SVG files (copy as-is)
  - Add logic to skip processing for animated GIFs (copy as-is)
  - Implement idempotency: Check if processed files exist and are newer than source
  - Use file checksums or timestamps to avoid re-processing
  - Log skipped files for transparency

  **Must NOT do**:
  - Don't skip non-animated images
  - Don't process SVGs (they'll break)
  - Don't re-process unchanged images

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: None needed
  - **Reason**: Logic additions to existing script

  **Parallelization**:
  - **Can Run In Parallel**: YES (Wave 2)
  - **Parallel Group**: Wave 2 (with Tasks 4, 5)
  - **Blocks**: None (Task 5 can run with this)
  - **Blocked By**: None

  **References**:
  - File type detection: Check extension and content-type
  - Animated GIF detection: ImageMagick identify -verbose gif | grep "Animation"
  - Checksum: Digest::MD5.file(path).hexdigest
  - Current caching: None (always re-downloads)

  **Acceptance Criteria**:
  - [ ] SVG files are copied without processing
  - [ ] Animated GIFs are copied without processing
  - [ ] Unchanged images are skipped on re-run
  - [ ] Log shows "Skipping [filename] - already processed"

  **QA Scenarios**:
  ```
  Scenario: Skip SVG files
    Tool: Bash
    Preconditions: WordPress has SVG attachment
    Steps:
      1. Add SVG to WordPress media
      2. Run: ruby scripts/fetch-images.rb
      3. Check output logs
    Expected Result: Log shows "Skipping SVG: [filename]"
    Failure Indicators: SVG processed/resized (would corrupt it)
    Evidence: .sisyphus/evidence/task-6-svg-skip.txt

  Scenario: Skip unchanged images
    Tool: Bash
    Preconditions: Images already processed
    Steps:
      1. Run: ruby scripts/fetch-images.rb (first time)
      2. Run: ruby scripts/fetch-images.rb (second time, immediately after)
      3. Check timestamps
    Expected Result: Second run completes faster, logs show skipped files
    Failure Indicators: Same processing time (re-processing everything)
    Evidence: .sisyphus/evidence/task-6-caching-times.txt
  ```

  **Evidence to Capture**:
  - [ ] task-6-svg-skip.txt
  - [ ] task-6-caching-times.txt

  **Commit**: YES
  - Message: `feat(scripts): add format exclusions and caching for image processing`
  - Files: `scripts/fetch-images.rb`
  - Pre-commit: Test with SVG and re-run scenario

- [x] 7. Create Hugo image partial with <picture> element

  **What to do**:
  - Create Hugo template partial at `hugo-site/layouts/partials/image.html`
  - Partial should render <picture> element with format fallbacks:
    - <source srcset="image.avif" type="image/avif">
    - <source srcset="image.webp" type="image/webp">
    - <img src="image.jpg" alt="...">
  - Support both content images and featured images
  - Handle case where WebP/AVIF don't exist (fallback to original only)
  - Update Stack theme to use this partial (may need to override theme files)

  **Must NOT do**:
  - Don't break existing image rendering
  - Don't require changes to all existing posts
  - Don't use JavaScript for format detection

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
  - **Skills**: None needed
  - **Reason**: Hugo template work requiring understanding of Stack theme structure

  **Parallelization**:
  - **Can Run In Parallel**: NO (Wave 3 sequential)
  - **Parallel Group**: Wave 3
  - **Blocks**: Task 8 (end-to-end testing)
  - **Blocked By**: Task 5 (needs processed images to test with)

  **References**:
  - Hugo image processing: `https://gohugo.io/content-management/image-processing/`
  - <picture> element MDN: `https://developer.mozilla.org/en-US/docs/Web/HTML/Element/picture`
  - Stack theme image handling: Check `hugo-site/themes/` or module cache

  **Acceptance Criteria**:
  - [ ] Partial created at `hugo-site/layouts/partials/image.html`
  - [ ] Partial renders <picture> with AVIF, WebP, and fallback sources
  - [ ] Hugo build succeeds without errors
  - [ ] Generated HTML contains proper <picture> structure

  **QA Scenarios**:
  ```
  Scenario: Verify Hugo partial exists
    Tool: Bash
    Preconditions: Partial file created
    Steps:
      1. Run: ls hugo-site/layouts/partials/image.html
      2. Run: cat hugo-site/layouts/partials/image.html
    Expected Result: File exists with <picture> element template
    Failure Indicators: File missing, syntax errors
    Evidence: .sisyphus/evidence/task-7-partial-content.txt

  Scenario: Build Hugo site with processed images
    Tool: Bash
    Preconditions: Processed images exist in static/images/
    Steps:
      1. Run: cd hugo-site && hugo --minify
      2. Run: grep -r '<picture>' public/posts/ | head -5
    Expected Result: Hugo builds successfully, HTML contains <picture> elements
    Failure Indicators: Build errors, no <picture> tags in output
    Evidence: .sisyphus/evidence/task-7-hugo-build.txt
  ```

  **Evidence to Capture**:
  - [ ] task-7-partial-content.txt
  - [ ] task-7-hugo-build.txt

  **Commit**: YES
  - Message: `feat(hugo): add image partial with AVIF/WebP format fallbacks`
  - Files: `hugo-site/layouts/partials/image.html`
  - Pre-commit: `hugo --minify` succeeds

- [ ] 8. Test end-to-end workflow locally

  **What to do**:
  - Run complete workflow locally:
    1. Start WordPress with test images
    2. Run fetch-images.rb
    3. Verify processed images exist (watermarked, WebP, AVIF)
    4. Build Hugo site
    5. Verify <picture> elements in output
    6. Serve locally and verify in browser
  - Test with various image types: JPEG, PNG, SVG, different sizes

  **Must NOT do**:
  - Don't skip manual verification in browser
  - Don't test only with one image type

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
  - **Skills**: None needed
  - **Reason**: Integration testing requiring multiple steps

  **Parallelization**:
  - **Can Run In Parallel**: NO (Wave 3 sequential)
  - **Parallel Group**: Wave 3
  - **Blocks**: Task 9 (CI verification - ensure local works first)
  - **Blocked By**: Task 5, Task 6, Task 7

  **References**:
  - Full workflow: See README.md "Testing" section
  - Local testing: `docker compose up`, `docker exec wp-builder ...`

  **Acceptance Criteria**:
  - [ ] Complete workflow runs without errors
  - [ ] Browser shows watermarked images
  - [ ] Network tab shows WebP/AVIF being served (if browser supports)
  - [ ] Fallback works in browsers without WebP/AVIF support

  **QA Scenarios**:
  ```
  Scenario: End-to-end workflow test
    Tool: Bash + Browser
    Preconditions: All previous tasks complete
    Steps:
      1. Start: docker compose up -d wordpress db builder
      2. Seed: ruby scripts/seed-posts.rb
      3. Fetch: ruby scripts/fetch-images.rb
      4. Verify: ls hugo-site/static/images/content/*/ (check .webp and .avif exist)
      5. Build: hugo -s hugo-site --minify
      6. Serve: cd hugo-site/public && python3 -m http.server 8080
      7. Open: http://localhost:8080 in browser
    Expected Result: Images load, watermark visible, modern formats served
    Failure Indicators: Broken images, no watermark, wrong formats
    Evidence: .sisyphus/evidence/task-8-browser-screenshot.png

  Scenario: Verify format negotiation
    Tool: Browser DevTools
    Preconditions: Site running locally
    Steps:
      1. Open DevTools Network tab
      2. Reload page
      3. Inspect image requests
    Expected Result: Browser requests AVIF or WebP (type column in Network tab)
    Failure Indicators: Only JPEG requested (no modern formats)
    Evidence: .sisyphus/evidence/task-8-network-tab.png
  ```

  **Evidence to Capture**:
  - [ ] task-8-browser-screenshot.png
  - [ ] task-8-network-tab.png

  **Commit**: NO (testing only)

- [ ] 9. Verify GitHub Actions CI workflow

  **What to do**:
  - Push all changes to a branch
  - Trigger GitHub Actions workflow manually
  - Verify build completes successfully
  - Check that image processing runs in CI
  - Verify deployment to Cloudflare Pages works

  **Must NOT do**:
  - Don't merge to main until CI passes
  - Don't skip CI logs review

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: None needed
  - **Reason**: CI verification, monitoring workflow

  **Parallelization**:
  - **Can Run In Parallel**: NO (Wave 4 sequential)
  - **Parallel Group**: Wave 4
  - **Blocks**: Task 10 (documentation - verify it works first)
  - **Blocked By**: All Wave 1-3 tasks

  **References**:
  - GitHub Actions: `.github/workflows/deploy.yml`
  - CI triggers: `workflow_dispatch` (manual), `push` to main

  **Acceptance Criteria**:
  - [ ] GitHub Actions workflow runs without errors
  - [ ] Image processing step completes in CI
  - [ ] Hugo build succeeds
  - [ ] Deploy to Cloudflare Pages succeeds
  - [ ] Live site shows optimized images

  **QA Scenarios**:
  ```
  Scenario: Trigger CI workflow
    Tool: GitHub Web UI or gh CLI
    Preconditions: Changes pushed to branch
    Steps:
      1. Run: gh workflow run deploy.yml --ref <branch-name>
      2. Or trigger via GitHub Actions UI
      3. Wait for completion
    Expected Result: Workflow status is "Success" (green checkmark)
    Failure Indicators: Red X, failed jobs
    Evidence: .sisyphus/evidence/task-9-ci-status.png

  Scenario: Verify image processing in CI logs
    Tool: GitHub Web UI
    Preconditions: Workflow completed
    Steps:
      1. Open workflow run logs
      2. Find "Fetch WordPress Content" step
      3. Look for image processing output
    Expected Result: Logs show "Processing: [image]", "Created .webp", etc.
    Failure Indicators: No image processing logs, errors
    Evidence: .sisyphus/evidence/task-9-ci-logs.txt
  ```

  **Evidence to Capture**:
  - [ ] task-9-ci-status.png
  - [ ] task-9-ci-logs.txt

  **Commit**: NO (CI verification)

- [x] 10. Create documentation

  **What to do**:
  - Create `docs/image-optimization.md` documenting:
    - How image processing works
    - What formats are generated
    - How to customize the watermark
    - Performance impact and build times
    - Troubleshooting common issues
  - Update main README.md with image optimization section

  **Must NOT do**:
  - Don't duplicate Hugo or ImageMagick docs
  - Don't write generic optimization advice

  **Recommended Agent Profile**:
  - **Category**: `writing`
  - **Skills**: None needed
  - **Reason**: Documentation writing

  **Parallelization**:
  - **Can Run In Parallel**: NO (Wave 4 sequential)
  - **Parallel Group**: Wave 4
  - **Blocks**: None (final task)
  - **Blocked By**: Task 9 (verify it works before documenting)

  **References**:
  - Existing docs: `docs/local-dev-setup.md`, `docs/testing.md`
  - README: `README.md` image troubleshooting section

  **Acceptance Criteria**:
  - [ ] `docs/image-optimization.md` created
  - [ ] README.md updated with image optimization section
  - [ ] Documentation covers watermark customization
  - [ ] Documentation covers format fallbacks

  **QA Scenarios**:
  ```
  Scenario: Verify documentation exists
    Tool: Bash
    Preconditions: Documentation written
    Steps:
      1. Run: ls docs/image-optimization.md
      2. Run: head -50 docs/image-optimization.md
    Expected Result: File exists with relevant content
    Failure Indicators: File missing, incomplete content
    Evidence: .sisyphus/evidence/task-10-docs-content.txt
  ```

  **Evidence to Capture**:
  - [ ] task-10-docs-content.txt

  **Commit**: YES
  - Message: `docs: add image optimization documentation`
  - Files: `docs/image-optimization.md`, `README.md`
  - Pre-commit: Files exist and are readable

---

## Final Verification Wave

> 4 review agents run in PARALLEL. ALL must APPROVE.

- [ ] F1. **Plan Compliance Audit** — `oracle`
  Read the plan end-to-end. For each "Must Have": verify implementation exists (read file, curl endpoint, run command). For each "Must NOT Have": search codebase for forbidden patterns. Check evidence files exist.
  Output: `Must Have [N/N] | Must NOT Have [N/N] | Tasks [N/N] | VERDICT: APPROVE/REJECT`

- [ ] F2. **Code Quality Review** — `unspecified-high`
  Review all changed files for: Ruby syntax errors, Hugo template errors, Dockerfile best practices. Check for hardcoded values, missing error handling, security issues.
  Output: `Syntax [PASS/FAIL] | Security [PASS/FAIL] | Best Practices [PASS/FAIL] | VERDICT`

- [ ] F3. **Real Manual QA** — `unspecified-high`
  Execute the full workflow:
  1. Start WordPress
  2. Run fetch-images.rb
  3. Build Hugo
  4. Verify images have watermarks
  5. Verify WebP/AVIF exist
  6. Verify HTML has <picture> elements
  Output: `Workflow [PASS/FAIL] | Images [N/N processed] | Formats [N/N variants] | VERDICT`

- [ ] F4. **Scope Fidelity Check** — `deep`
  For each task: read "What to do", read actual diff. Verify 1:1 match. Check "Must NOT do" compliance. Detect scope creep.
  Output: `Tasks [N/N compliant] | Scope Creep [CLEAN/N issues] | VERDICT`

---

## Commit Strategy

- **Task 1**: `chore(docker): add ImageMagick and image optimization tools`
- **Task 2**: `ci(github): add image processing dependencies to workflow`
- **Task 3**: `chore(deps): add mini_magick and image_optim gems`
- **Task 4**: `feat(scripts): add watermark generator script`
- **Task 5**: `feat(scripts): add image processing with watermark and modern formats`
- **Task 6**: `feat(scripts): add format exclusions and caching for image processing`
- **Task 7**: `feat(hugo): add image partial with AVIF/WebP format fallbacks`
- **Task 10**: `docs: add image optimization documentation`

---

## Success Criteria

### Verification Commands
```bash
# Verify ImageMagick installation
docker run wp-builder convert --version

# Test image processing
docker exec wp-builder ruby scripts/fetch-images.rb

# Verify Hugo builds
docker exec wp-builder hugo -s /app/hugo-site --minify

# Check processed images exist
ls hugo-site/static/images/content/*/
# Should see: original.jpg, original.webp, original.avif

# Check HTML output
grep -r '<picture>' hugo-site/public/posts/ | head -3
```

### Final Checklist
- [ ] All images from WordPress are watermarked
- [ ] WebP and AVIF variants exist for all photos
- [ ] SVG and GIF files preserved unchanged
- [ ] Hugo templates serve modern formats with fallback
- [ ] GitHub Actions workflow passes
- [ ] Cloudflare Pages deployment successful
- [ ] Documentation complete

---

## Storage Impact

**Before optimization**: Original images only
**After optimization**: Original + WebP + AVIF

| Format | Size (typical) |
|--------|----------------|
| Original JPEG | 100% (baseline) |
| WebP (80% quality) | ~70% of original |
| AVIF (50% quality) | ~50% of original |

**Total storage**: ~2.2x original size

**Benefits**:
- ~30% bandwidth savings with WebP
- ~50% bandwidth savings with AVIF (supported browsers)
- Improved page load times
- Reduced Cloudflare egress costs

---

## Troubleshooting

### Issue: "convert: command not found"
**Cause**: ImageMagick not installed in container/CI
**Fix**: Verify Tasks 1 and 2 completed successfully

### Issue: Watermark not visible
**Cause**: Opacity too low or watermark file missing
**Fix**: Check `hugo-site/static/images/watermark.png` exists, adjust opacity in script

### Issue: WebP/AVIF not being served
**Cause**: Browser doesn't support format or Hugo template not working
**Fix**: Check browser DevTools Network tab, verify `<picture>` element in HTML

### Issue: Build timeout in CI
**Cause**: Processing too many images
**Fix**: Implement better caching (Task 6), or reduce number of images processed per build

---

*Plan generated: 2026-02-19*
*Metis consultation: Yes - all critical gaps addressed*
*Draft cleaned up: After plan completion*
