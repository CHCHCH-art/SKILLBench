# Brand & Marketing Assets

Guidelines for generating logos, marketing materials, and brand-consistent imagery.

**Model selection:** Use pro/quality models for final brand assets. Quality matters for marketing materials; use faster models only for initial exploration. See [models.md](models.md) for discovery commands.

## Logo Generation

AI-generated logos work best as starting points or concepts, not final production assets.

### Limitations to Know

- **Text rendering:** AI struggles with text in images—letters may be malformed
- **Vector output:** AI generates raster images; conversion to vector requires post-processing
- **Uniqueness:** Cannot guarantee generated logos aren't similar to existing brands
- **Consistency:** Regenerating won't produce identical results

### Effective Logo Prompts

```bash
# Abstract/symbol logos (AI handles these best)
bun scripts/fal-generate.ts "abstract geometric logo, three interlocking shapes, modern, minimal"

# Lettermark logos
bun scripts/fal-generate.ts "letter M logo, bold geometric construction, single color, logo design"

# Icon-style logos
bun scripts/fal-generate.ts "mountain peak logo, minimalist, clean lines, outdoor brand style"
```

### Logo Prompt Structure

```
[subject] + [style] + [constraints] + "logo design"
```

**Subject:** What the logo depicts
- "letter A" / "abstract wave" / "tree silhouette"

**Style modifiers:**
- "minimalist" / "modern" / "geometric"
- "flat design" / "line art" / "solid shapes"
- "professional" / "playful" / "elegant"

**Constraints:**
- "single color" / "two-color" / "monochrome"
- "no gradients" / "clean lines"
- "scalable" / "works at small sizes"

### What to Avoid

```bash
# Bad: Complex scenes don't work as logos
bun scripts/fal-generate.ts "detailed forest scene with animals"  # ❌

# Bad: Text-heavy logos
bun scripts/fal-generate.ts "logo with company name 'TechCorp Solutions'"  # ❌

# Good: Simple symbol
bun scripts/fal-generate.ts "abstract tech logo, circuit-inspired, geometric, minimal"  # ✓
```

## Marketing Imagery

### Hero Images

```bash
# Website hero banners
bun scripts/fal-generate.ts "modern workspace with laptop, soft lighting, minimal, tech company style" \
  --size landscape_16_9

# Product-focused
bun scripts/fal-generate.ts "smartphone on marble surface, premium product photography style"
```

### Social Media Assets

```bash
# Instagram square
bun scripts/fal-generate.ts "lifestyle flat lay, coffee and notebook, warm tones, instagram aesthetic" \
  --size square

# LinkedIn banner (landscape)
bun scripts/fal-generate.ts "abstract professional background, blue corporate colors, subtle geometric pattern" \
  --size landscape_16_9

# Twitter/X header
bun scripts/fal-generate.ts "modern gradient background, tech aesthetic, wide banner format"
```

### Blog Thumbnails

```bash
# Consistent style across posts
bun scripts/fal-generate.ts "abstract illustration, topic: [TOPIC], flat design, vibrant colors, blog thumbnail"

# With brand colors
bun scripts/fal-generate.ts "conceptual illustration about productivity, brand colors #3B82F6 and #10B981"
```

## Style Consistency

### Using Reference Images

```bash
# First, establish your style
bun scripts/fal-generate.ts "abstract tech illustration, flat design, purple and blue" --out brand_style.png

# Then use as reference for subsequent assets
bun scripts/fal-generate.ts "illustration about cloud computing, match style exactly" \
  --edit brand_style.png --out cloud_article.png
```

### Style Keywords Library

Build a consistent prompt suffix for your brand:

```
BRAND_STYLE="flat design, modern, clean lines, brand colors purple and teal, minimal shadows"

bun scripts/fal-generate.ts "team collaboration concept, $BRAND_STYLE"
bun scripts/fal-generate.ts "data analytics concept, $BRAND_STYLE"
```

### Color Specification

```bash
# Hex codes
bun scripts/fal-generate.ts "abstract background, primary color #FF6B35, secondary #004E89"

# Descriptive
bun scripts/fal-generate.ts "warm sunset gradient background, coral to deep orange"

# Reference-based
bun scripts/fal-generate.ts "match the color palette from the reference image" --edit brand_guide.png
```

## Product Photography Style

### Lifestyle Shots

```bash
bun scripts/fal-generate.ts "product on wooden desk, natural window light, minimal props, lifestyle photography"
bun scripts/fal-generate.ts "skincare bottle in bathroom setting, marble surfaces, soft morning light"
```

### Clean Product Shots

```bash
bun scripts/fal-generate.ts "product floating on white background, soft shadows, studio lighting, commercial photography"
bun scripts/fal-generate.ts "tech device on gradient background, reflective surface, premium feel"
```

### Contextual Shots

```bash
bun scripts/fal-generate.ts "person using laptop in coffee shop, focus on screen, authentic moment"
bun scripts/fal-generate.ts "hands holding smartphone, outdoor urban setting, natural"
```

## Illustration Styles

### Flat Design

```bash
bun scripts/fal-generate.ts "flat design illustration, people working together, geometric shapes, limited palette"
```

### Line Art

```bash
bun scripts/fal-generate.ts "continuous line drawing, minimalist portrait, single stroke style"
```

### Isometric

```bash
bun scripts/fal-generate.ts "isometric office scene, 3D style, colorful, tech company illustration"
```

### Abstract/Conceptual

```bash
bun scripts/fal-generate.ts "abstract representation of growth, flowing organic shapes, gradient colors"
```

## Post-Processing for Brand Use

### Format Conversion

```bash
# High-res for print
convert web_image.png -resize 3000x3000 -density 300 print_ready.png

# Optimize for web
convert image.png -strip -quality 85 optimized.jpg

# Create multiple sizes
convert hero.png -resize 1920x1080 hero_desktop.png
convert hero.png -resize 768x432 hero_tablet.png
convert hero.png -resize 375x211 hero_mobile.png
```

### Background Removal

```bash
# For product shots needing transparent background
convert product.png -fuzz 10% -transparent white product_transparent.png
```

### Color Adjustment

```bash
# Adjust to match brand colors
convert image.png -modulate 100,120,95 brand_adjusted.png

# Convert to brand palette
convert image.png -remap brand_palette.png branded.png
```

## Template Approach

For consistent marketing assets, create a prompt template:

```markdown
## [Brand] Image Generation Template

**Base style:** flat design, modern, clean
**Colors:** Primary #3B82F6, Secondary #10B981, Accent #F59E0B
**Constraints:** no gradients, minimal shadows, geometric shapes
**Mood:** professional, approachable, innovative

**Prompt format:**
"[subject], flat design, modern, clean, colors blue #3B82F6 and green #10B981, professional mood, minimal"
```

## Legal Considerations

⚠️ **Important:**
- AI-generated images may not be copyrightable in all jurisdictions
- Cannot guarantee uniqueness—run reverse image search on important assets
- For trademarked logos, consult legal counsel before use
- Keep generation prompts documented for provenance
