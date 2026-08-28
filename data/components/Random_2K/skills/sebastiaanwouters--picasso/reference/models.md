# Model Selection

Choose the right model for your asset type. **Iterate cheap, upgrade for finals.**

## Strategy

1. **Exploration phase** → Use fast/cheap models (most outputs get discarded)
2. **Final output** → Upgrade to quality model (when it's the actual deliverable)
3. **Post-process** → ImageMagick cleanup is free, regeneration isn't

## Discovering Models

```bash
# List all text-to-image models
curl -s "https://api.fal.ai/v1/models?category=text-to-image&status=active" \
  -H "Authorization: Key $FAL_API_KEY" | jq '.models[] | {id: .endpoint_id, name: .metadata.display_name}'

# List image editing models
curl -s "https://api.fal.ai/v1/models?category=image-to-image&status=active" \
  -H "Authorization: Key $FAL_API_KEY" | jq '.models[] | {id: .endpoint_id, name: .metadata.display_name}'

# Search for specific capability
curl -s "https://api.fal.ai/v1/models?q=pixel+art&status=active" \
  -H "Authorization: Key $FAL_API_KEY" | jq '.models'

# Get model details with pricing
curl -s "https://api.fal.ai/v1/models?endpoint_id=fal-ai/flux/dev&expand=openapi-3.0" \
  -H "Authorization: Key $FAL_API_KEY" | jq '.'
```

## Model Selection by Asset Type

### Game Assets (Sprites, Pixel Art, Tilesets)

**Priority:** Style consistency, clean edges, pixel-perfect output

Look for models with:
- "pixel art" or "stylized" in tags
- Good at maintaining sharp edges
- Consistent style across generations

**Query:**
```bash
curl -s "https://api.fal.ai/v1/models?q=pixel+stylized&category=text-to-image" \
  -H "Authorization: Key $FAL_API_KEY"
```

**Considerations:**
- Speed matters for iterative sprite work
- Smaller/faster models often sufficient for simple sprites
- Use edit endpoints for style consistency across frames

### Icons & Favicons

**Priority:** Clean lines, works at small sizes, simple shapes

Look for models with:
- Good at geometric/minimal outputs
- Clean vector-like results
- Fast generation for iteration

**Query:**
```bash
curl -s "https://api.fal.ai/v1/models?q=logo+minimal&category=text-to-image" \
  -H "Authorization: Key $FAL_API_KEY"
```

**Considerations:**
- High-quality models overkill for simple icons
- Fast models preferred for trying variations
- Output will be downscaled anyway

### Brand Assets & Marketing

**Priority:** Highest quality, photorealistic or polished illustration

Look for models with:
- "pro" or "ultra" variants
- Higher resolution output
- Better prompt adherence
- Advanced text rendering (if needed)

**Query:**
```bash
curl -s "https://api.fal.ai/v1/models?q=pro+high+quality&category=text-to-image" \
  -H "Authorization: Key $FAL_API_KEY"
```

**Considerations:**
- Quality over speed for final brand assets
- Use pro/edit models for refinement
- Higher resolution options for print materials

### Photo Editing & Compositing

**Priority:** Natural blending, accurate edits

Look for models with:
- Image-to-image capability
- Inpainting support
- High-resolution editing

**Query:**
```bash
curl -s "https://api.fal.ai/v1/models?category=image-to-image&q=edit" \
  -H "Authorization: Key $FAL_API_KEY"
```

## Cost vs Quality Tradeoffs

| Use Case | Model Tier | Why |
|----------|------------|-----|
| Concept exploration | Fast/cheap | Many iterations, most get discarded |
| Sprite frames | Fast/cheap | Post-processed anyway, speed matters |
| App icons/favicons | Fast/cheap | Downscaled to 32px, quality irrelevant |
| Logo concepts | Fast/cheap | Will be refined/vectorized anyway |
| Final brand logo | Standard | Quality visible in deliverable |
| Marketing hero image | Pro | Quality is the product |
| Print materials | Pro + upscale | Resolution and detail critical |

## Using the Script

The `fal-generate.ts` script accepts `--model` to override the default:

```bash
# Check default model behavior
bun scripts/fal-generate.ts "test prompt" --help

# Use specific model
bun scripts/fal-generate.ts "pixel art character" --model fal-ai/[model-id]

# For editing, script auto-detects edit endpoint
bun scripts/fal-generate.ts "modify this" --edit image.png
```

## Model Categories on fal.ai

- `text-to-image` - Generate images from prompts
- `image-to-image` - Edit/transform existing images
- `image-to-video` - Animate images
- `text-to-video` - Generate videos from prompts
- `upscaling` - Increase image resolution

Browse all: https://fal.ai/models
