# Image Generation

Core principles for generating high-quality images from text prompts.

**Model selection:** Use quality/pro models for final outputs. Fast models for exploration and iteration. See [models.md](models.md) for discovery.

## Prompt Structure

A well-structured prompt includes these elements in order of importance:

```
[Subject] + [Style/Medium] + [Lighting] + [Composition] + [Color/Mood] + [Details]
```

**Universal template:**
```
"Subject, medium, style, lighting, framing, mood, palette"
```

**Example:**
```
"Portrait of a barista, film photo, soft rim light, 50mm close-up, warm mood, teal-orange palette"
```

## Subject Description

Be specific about the main focus:

```bash
# Vague (bad)
bun scripts/fal-generate.ts "a cool landscape"

# Specific (good)  
bun scripts/fal-generate.ts "alpine landscape, dramatic snow-capped peaks, winding river, golden hour"
```

**Tips:**
- Name concrete objects, materials, textures
- Specify age, ethnicity, clothing for people
- Include spatial relationships: "in the foreground", "behind", "to the left"

## Style & Medium

Reference artistic styles, mediums, or eras:

| Category | Examples |
|----------|----------|
| Photography | "35mm film", "DSLR", "Polaroid", "macro shot", "aerial view" |
| Art styles | "oil painting", "watercolor", "charcoal sketch", "digital art" |
| Era/movement | "art deco", "baroque", "cyberpunk", "1920s travel poster" |
| Rendering | "photorealistic", "low poly", "isometric", "flat design" |

**Avoid naming living artists.** Describe inspirations by genre, era, or technique instead.

## Lighting

Lighting dramatically affects mood and realism:

| Lighting Type | Effect | Prompt Keywords |
|---------------|--------|-----------------|
| Golden hour | Warm, romantic | "golden hour", "sunset light", "warm tones" |
| Blue hour | Cool, cinematic | "blue hour", "twilight", "cool ambient" |
| Studio | Clean, professional | "studio lighting", "softbox", "even light" |
| Rim light | Separation, drama | "rim light", "backlit", "edge lighting" |
| Chiaroscuro | High contrast, dramatic | "dramatic shadows", "strong contrast", "Rembrandt lighting" |
| Overcast | Soft, diffused | "overcast", "soft diffused light", "no harsh shadows" |

**Volumetric lighting:**
```
"light rays penetrating morning fog", "visible beams in smoky environment", "god rays through clouds"
```

## Composition & Camera

Control framing and perspective:

```bash
# Camera terms
bun scripts/fal-generate.ts "portrait, 85mm lens, shallow depth of field, bokeh background"

# Composition rules
bun scripts/fal-generate.ts "landscape, rule of thirds, leading lines, wide angle"
```

**Useful terms:**
- Focal length: "35mm wide", "50mm normal", "85mm portrait", "200mm telephoto"
- Depth: "shallow depth of field", "bokeh", "everything in focus"
- Angle: "overhead", "low angle", "eye level", "Dutch angle"
- Framing: "close-up", "medium shot", "wide shot", "extreme close-up"

## Color & Mood

Specify color palettes and emotional tone:

```bash
# Color grading
bun scripts/fal-generate.ts "cinematic still, teal-and-orange color grade"

# Mood descriptors
bun scripts/fal-generate.ts "moody, atmospheric, melancholic, muted colors"
```

**Color approaches:**
- Named palettes: "pastel", "earth tones", "neon", "monochromatic"
- Film looks: "Kodak Portra", "Fujifilm", "cross-processed"
- Specific colors: "primary blue #3B82F6", "warm copper accent"

## Quality & Resolution

Boost output quality with specific terms:

```bash
bun scripts/fal-generate.ts "detailed landscape, 8K resolution, ultra detailed, sharp focus, high dynamic range"
```

**Quality keywords:**
- "high detail", "ultra detailed", "intricate"
- "sharp focus", "crisp"
- "8K", "high resolution"
- "professional", "masterful"

## Negative Prompting

Some models support negative prompts to exclude unwanted elements:

```
Negative: "blurry, low quality, distorted, watermark, text, extra fingers, deformed"
```

**Common exclusions:**
- Quality issues: "blurry", "low resolution", "noisy", "artifacts"
- Anatomical: "extra fingers", "deformed hands", "distorted face"
- Unwanted elements: "watermark", "signature", "text", "logo"

## Iteration Strategy

1. **Start broad** - Generate with a simple prompt to establish direction
2. **Refine one variable** - Change lighting, composition, or style
3. **Compare outputs** - Generate multiple variations
4. **Lock in winners** - Use `--edit` with successful outputs as reference

```bash
# Iteration example
# v1: Base concept
bun scripts/fal-generate.ts "portrait, natural light" --num 4

# v2: Refine lighting
bun scripts/fal-generate.ts "portrait, golden hour backlight" --num 4

# v3: Add mood
bun scripts/fal-generate.ts "portrait, golden hour backlight, moody shadows, film grain" --num 4
```

## Common Pitfalls

| Problem | Cause | Solution |
|---------|-------|----------|
| Generic results | Vague prompt | Add specific details, style references |
| Wrong style | Conflicting keywords | Simplify prompt, be consistent |
| Bad anatomy | Complex poses | Simplify pose, avoid hands when possible |
| Text issues | AI struggles with text | Avoid text in image, add in post |
| Inconsistent results | No style anchor | Use reference images via `--edit` |

## Aspect Ratios

Match aspect ratio to use case:

| Use Case | Ratio | Script Flag |
|----------|-------|-------------|
| Social square | 1:1 | `--size square` |
| Portrait/story | 9:16 | `--size portrait_9_16` |
| Landscape banner | 16:9 | `--size landscape_16_9` |
| Standard photo | 4:3 | `--size landscape_4_3` |
| Cinematic | 21:9 | `--size landscape_21_9` |
