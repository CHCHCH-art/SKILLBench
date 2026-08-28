# Image Editing

Techniques for modifying existing images: inpainting, outpainting, compositing, and style transfer.

**Model selection:** Use image-to-image models with good blending capabilities. Pro/edit variants typically produce more natural results. See [models.md](models.md) for discovery.

## Editing Modes

### Inpainting (Edit Within Image)

Modify specific areas while preserving the rest:

```bash
# Object replacement
bun scripts/fal-generate.ts "replace the red car with a blue motorcycle" --edit photo.png

# Add elements
bun scripts/fal-generate.ts "add a golden retriever sitting on the couch" --edit living_room.png

# Remove elements  
bun scripts/fal-generate.ts "remove the person, fill with background" --edit crowd.png
```

**Best practices:**
- Be specific about what to change AND what to preserve
- Describe the area: "in the bottom left corner", "on the table"
- Match existing style: "same lighting", "consistent with surroundings"

### Outpainting (Extend Image)

Expand beyond original borders:

```bash
# Extend for different aspect ratio
bun scripts/fal-generate.ts "extend this portrait to landscape format, continue the forest background" \
  --edit portrait.png --size landscape_16_9

# Add context
bun scripts/fal-generate.ts "extend the scene to show more of the room" --edit cropped.png
```

**Tips:**
- Describe what should appear in extended areas
- "Continue the pattern", "extend the sky", "show more of the environment"
- Best results when extending consistent backgrounds

### Style Transfer

Apply artistic styles to existing images:

```bash
# Artistic styles
bun scripts/fal-generate.ts "transform to oil painting style, impressionist" --edit photo.png

# Film looks
bun scripts/fal-generate.ts "apply vintage film aesthetic, faded colors, grain" --edit modern.png

# Era/mood
bun scripts/fal-generate.ts "make it look like a 1970s photograph" --edit portrait.png
```

### Compositing (Multi-Image)

Combine multiple images into one scene:

```bash
# Person + background
bun scripts/fal-generate.ts "place the person from first image into the beach scene from second" \
  --edit person.png --edit beach.png --out composite.png

# Style reference
bun scripts/fal-generate.ts "apply the color palette and mood from the second image to the first" \
  --edit subject.png --edit style_reference.png
```

**Image order matters:**
- First image: primary subject/content
- Second image: context, style, or background

## Prompt Strategies for Edits

### Be Explicit About Changes

```bash
# Vague (unpredictable)
bun scripts/fal-generate.ts "make it better" --edit photo.png

# Specific (controlled)
bun scripts/fal-generate.ts "brighten the shadows, add warm color grade, increase contrast" --edit photo.png
```

### Describe Spatial Relationships

```bash
# Where to add
bun scripts/fal-generate.ts "add a coffee cup on the left side of the desk" --edit desk.png

# Relative position
bun scripts/fal-generate.ts "place a cat behind the sofa, partially visible" --edit room.png
```

### Preserve What Matters

```bash
# Explicit preservation
bun scripts/fal-generate.ts "change the sky to sunset, keep the building exactly as is" --edit city.png

# Style matching
bun scripts/fal-generate.ts "add flowers to the vase, match the lighting and style of the room" --edit interior.png
```

## Common Edit Tasks

### Background Replacement

```bash
# Solid background
bun scripts/fal-generate.ts "replace background with pure white studio backdrop" --edit product.png

# Environment change
bun scripts/fal-generate.ts "change background to a cozy coffee shop interior, warm lighting" --edit portrait.png

# Abstract
bun scripts/fal-generate.ts "replace background with soft gradient, purple to blue" --edit headshot.png
```

### Object Manipulation

```bash
# Color change
bun scripts/fal-generate.ts "change the shirt color from blue to red" --edit person.png

# Object swap
bun scripts/fal-generate.ts "replace the laptop with a book" --edit desk.png

# Add accessories
bun scripts/fal-generate.ts "add sunglasses to the person" --edit portrait.png
```

### Enhancement

```bash
# Quality improvement
bun scripts/fal-generate.ts "enhance details, improve sharpness, reduce noise" --edit lowres.png

# Lighting fix
bun scripts/fal-generate.ts "correct the harsh shadows, add fill light" --edit portrait.png

# Color correction
bun scripts/fal-generate.ts "fix the white balance, remove the yellow tint" --edit indoor.png
```

## High Resolution Editing

For detailed edits, use pro/high-res models:

```bash
bun scripts/fal-generate.ts "refine facial details, enhance skin texture" \
  --edit portrait.png --resolution 2K --out hires.png
```

Resolution options: `1K`, `2K`, `4K`

## Seamless Blending Tips

### Match Lighting

```bash
# Describe existing light
bun scripts/fal-generate.ts "add a vase, lit from the window on the left, soft shadows to the right" \
  --edit table.png
```

### Match Style

```bash
# Reference the image style
bun scripts/fal-generate.ts "add a modern chair, same minimalist aesthetic as the room" --edit interior.png
```

### Edge Handling

For clean composites:
- Extend selection area slightly beyond the object
- Use "blend seamlessly", "natural transition" in prompts
- Post-process with ImageMagick for fine adjustments

## Troubleshooting Edits

| Issue | Cause | Solution |
|-------|-------|----------|
| Edit doesn't match lighting | No lighting description | Add "match existing lighting", describe light direction |
| Jarring edges | Hard blend boundaries | Request "seamless blend", extend edit area |
| Wrong object generated | Vague description | Be more specific about shape, size, color |
| Unwanted changes | Too broad a prompt | Specify "only change X, keep everything else" |
| Style mismatch | No style reference | Add "same style as original", describe aesthetics |

## Iterative Editing Workflow

1. **Initial edit** - Make the primary change
2. **Review** - Check lighting, edges, style consistency
3. **Refine** - Edit the result to fix issues
4. **Polish** - Use specialized tools (upscaling, color correction)

```bash
# Step 1: Add object
bun scripts/fal-generate.ts "add a plant in the corner" --edit room.png --out step1.png

# Step 2: Fix lighting
bun scripts/fal-generate.ts "adjust plant lighting to match room, add shadow" --edit step1.png --out step2.png

# Step 3: Final polish
bun scripts/fal-generate.ts "enhance details, ensure seamless integration" --edit step2.png --out final.png
```
