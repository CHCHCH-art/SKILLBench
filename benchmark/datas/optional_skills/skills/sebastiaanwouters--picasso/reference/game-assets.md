# Game Asset Generation

Game assets require special attention to consistency, alignment, and technical constraints that general image generation doesn't address.

**Model selection:** Use fast/stylized models for sprites. Speed enables iteration; style consistency matters more than photorealism. See [models.md](models.md) for discovery commands.

## Spritesheets

AI models struggle with grid alignment. The most reliable approach is generating frames individually.

### Recommended Workflow

```bash
# Generate individual frames, then combine manually
bun scripts/fal-generate.ts "knight character, side view, idle pose frame 1, pixel art, transparent background" --out frame1.png
bun scripts/fal-generate.ts "knight character, side view, idle pose frame 2, pixel art, transparent background" --out frame2.png

# Combine with ImageMagick (ensures perfect alignment)
convert frame1.png frame2.png frame3.png +append spritesheet.png

# Or create a grid (e.g., 4x2 for 8 frames)
montage frame*.png -tile 4x2 -geometry +0+0 spritesheet.png
```

### Prompt Strategies for Consistent Frames

**Pose specification:**
- "frame 1 of 6, left foot forward, arms at sides"
- "mid-stride running pose, right leg extended"
- "attack animation wind-up frame"

**Consistency keywords:**
- "same character, same proportions, same lighting"
- "identical style to reference"
- "uniform scale and positioning"

**Framing:**
- "centered in frame, transparent background"
- "full body visible, padding around character"
- "character on baseline, no cropping"

### Common Problems and Fixes

| Issue | Cause | Fix |
|-------|-------|-----|
| Characters drift position | No anchor point specified | Add "character centered on baseline" |
| Inconsistent sizes | Scale not locked | Specify "exactly 32x32 pixels" or "same scale" |
| Cut-off limbs | Tight framing | Add "full body visible, generous padding" |
| Style variation | Regeneration drift | Use `--edit` with first frame as reference |
| Anti-aliasing on pixel art | Default smoothing | Add "no anti-aliasing, sharp pixels" |

### Using Edit Mode for Consistency

```bash
# Generate base frame
bun scripts/fal-generate.ts "warrior idle pose, pixel art, transparent" --out frame1.png

# Use as reference for subsequent frames
bun scripts/fal-generate.ts "same warrior, walking pose frame 2, match style exactly" \
  --edit frame1.png --out frame2.png
```

## Pixel Art

True pixel art requires specific constraints that prevent AI from generating "pixel art style" images.

### Resolution Control

```bash
# Specify exact dimensions
bun scripts/fal-generate.ts "16x16 sword icon, pixel art" --out sword.png

# Common game resolutions
# 8x8   - tiny icons, inventory slots
# 16x16 - small sprites, items
# 32x32 - standard character sprites
# 64x64 - larger characters, detailed items
# 128x128 - boss sprites, detailed scenes
```

### Palette Control

```bash
# Limited palettes
bun scripts/fal-generate.ts "character sprite, 8-color palette, NES style" --out char.png
bun scripts/fal-generate.ts "forest tileset, 16-color palette, GBA style" --out forest.png
```

**Era references for style:**
- "NES style" - 4 colors per sprite, chunky pixels
- "SNES style" - 16 colors, more detail
- "GBA style" - 256 colors, smooth gradients
- "PS1 style" - low-poly 3D look, dithering

### Anti-aliasing Prevention

```bash
bun scripts/fal-generate.ts "pixel art character, no anti-aliasing, sharp edges, hard pixels"
```

**Keywords:** "no smoothing", "crisp pixels", "no blending", "hard edges"

## Tilesets & Seamless Textures

### Seamless Textures

```bash
# For textures that tile perfectly
bun scripts/fal-generate.ts "seamless grass texture, top-down view, tileable pattern" --size square

# Environment textures
bun scripts/fal-generate.ts "seamless stone wall texture, repeating, game asset" --size square
```

**Critical keywords:**
- "seamless" / "tileable" / "repeating pattern"
- "flat lighting, no directional shadows" (prevents visible seams)
- "top-down orthographic view" for 2D tiles
- "even distribution" for scatter textures

### Tileset Pieces

Generate pieces separately for best results:

```bash
# 9-slice tileset components
bun scripts/fal-generate.ts "stone platform, center tile, flat top, game tileset" --out center.png
bun scripts/fal-generate.ts "stone platform, left edge tile, game tileset" --out left.png
bun scripts/fal-generate.ts "stone platform, corner tile, top-left, game tileset" --out corner_tl.png
```

### Isometric Tiles

```bash
bun scripts/fal-generate.ts "isometric grass tile, 64x32, game asset, clean edges"
bun scripts/fal-generate.ts "isometric stone block, 2:1 ratio, pixel art"
```

## Character Rotations

Multi-directional sprites for top-down or isometric games.

### 4-Direction Set

```bash
bun scripts/fal-generate.ts "warrior facing south, front view, pixel art" --out south.png
bun scripts/fal-generate.ts "warrior facing north, back view, pixel art, same character" --out north.png
bun scripts/fal-generate.ts "warrior facing east, side view, pixel art, same character" --out east.png
bun scripts/fal-generate.ts "warrior facing west, side view, pixel art, same character" --out west.png
```

### 8-Direction Set

Add diagonals:
- "facing southeast, 3/4 front view"
- "facing northwest, 3/4 back view"

### Consistency via Edit Mode

```bash
# Base character
bun scripts/fal-generate.ts "knight character, facing south, full body" --out base.png

# Rotate using edit with explicit direction
bun scripts/fal-generate.ts "rotate this character to face east, same style" \
  --edit base.png --out east.png
```

## Post-Processing

AI output typically needs cleanup before game integration.

### Resize to Exact Dimensions

```bash
# Force exact size (may distort)
convert sprite.png -resize 32x32! sprite_32.png

# Resize preserving aspect, add padding
convert sprite.png -resize 32x32 -gravity center -extent 32x32 sprite_32.png

# Nearest-neighbor for pixel art (no blur)
convert sprite.png -filter point -resize 64x64 sprite_2x.png
```

### Fix Anti-aliasing

```bash
# Posterize to reduce colors (removes smooth gradients)
convert sprite.png -posterize 8 clean.png

# Threshold for hard edges
convert sprite.png -threshold 50% binary.png
```

### Batch Processing

```bash
# Uniform size for all frames
for f in frame*.png; do
  convert "$f" -gravity center -extent 64x64 "fixed_$f"
done

# Create spritesheet from frames
montage fixed_frame*.png -tile 8x1 -geometry +0+0 -background none spritesheet.png
```

### Transparency Cleanup

```bash
# Remove background color
convert sprite.png -fuzz 10% -transparent white clean.png

# Trim transparent edges
convert sprite.png -trim +repage trimmed.png
```

## Animation Guidelines

### Walk Cycles

Standard frame counts:
- 4 frames: minimal, retro feel
- 6 frames: smooth, common for pixel art
- 8 frames: very smooth, higher-res sprites

Prompt each frame explicitly:
1. "standing neutral, weight centered"
2. "right foot forward, left foot pushing off"
3. "mid-stride, legs spread"
4. "left foot forward, right foot pushing off"

### Attack Animations

- Wind-up frame (anticipation)
- Strike frames (1-3)
- Follow-through frame
- Recovery frame

### Idle Animations

Subtle movement:
- "idle pose, slight breathing motion"
- "idle, weight shifting"
- "idle, blinking"
