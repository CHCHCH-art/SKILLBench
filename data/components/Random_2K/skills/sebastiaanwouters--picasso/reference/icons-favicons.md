# Icons & Favicons

Small icons require special consideration—detail must be readable at tiny sizes.

**Model selection:** Use fast models—icons are heavily post-processed anyway. Quality models are overkill for simple geometric shapes. See [models.md](models.md) for discovery commands.

## Size Requirements

### Favicon Sizes

| Use Case | Size | Format |
|----------|------|--------|
| Browser tab | 16×16, 32×32 | ICO, PNG |
| Bookmark bar | 16×16 | ICO, PNG |
| Windows taskbar | 32×32 | ICO |
| Apple Touch Icon | 180×180 | PNG |
| Android Chrome | 192×192 | PNG |
| Windows tile | 270×270 | PNG |

### App Icon Sizes

| Platform | Required Size |
|----------|---------------|
| iOS App Store (master) | 1024×1024 |
| Android Play Store | 512×512 |
| Android adaptive icon | 108×108 dp |

## Generation Strategy

Always generate at largest needed size first, then downscale:

```bash
# Generate at 1024x1024 for maximum flexibility
bun scripts/fal-generate.ts "minimalist letter A logo, flat design, single color" \
  --size square --out icon_master.png

# Create favicon set
convert icon_master.png -resize 32x32 favicon.ico
convert icon_master.png -resize 16x16 favicon-16.png
convert icon_master.png -resize 180x180 apple-touch-icon.png
convert icon_master.png -resize 192x192 android-chrome-192.png
convert icon_master.png -resize 512x512 android-chrome-512.png
```

## Prompt Guidelines

### Simplicity is Critical

At 16×16 pixels, complex designs become unreadable blobs.

**Good prompts:**
- "single letter M, bold geometric, solid color"
- "simple lightning bolt icon, minimal"
- "abstract circle with dot, flat design"

**Bad prompts:**
- "detailed dragon breathing fire" (too complex)
- "photo-realistic coffee cup" (loses detail)
- "intricate Celtic knot pattern" (unreadable small)

### Key Prompt Elements

```bash
# Structure: subject + style + constraints
bun scripts/fal-generate.ts "letter S, geometric, flat design, single object centered, no text, solid background"
```

**Subject:** Keep to 1-2 simple elements
- Single letter or symbol
- Simple geometric shape
- Minimal abstract form

**Style modifiers:**
- "flat design" / "minimal" / "simple"
- "geometric" / "clean lines"
- "solid colors" / "no gradients"
- "bold" / "high contrast"

**Constraints:**
- "single object centered"
- "no text" (unless the icon IS text)
- "solid background" or "transparent background"
- "square format"

### Color Considerations

```bash
# High contrast for visibility
bun scripts/fal-generate.ts "icon, dark symbol on light background, high contrast"

# Brand colors
bun scripts/fal-generate.ts "app icon, #3B82F6 blue background, white symbol"
```

**Tips:**
- Max 2 colors for small icons
- Avoid similar hues that blend at small sizes
- Test in both light and dark mode contexts
- Saturated colors work better than muted

## App Icon Specifics

### iOS Guidelines

```bash
# iOS icons have rounded corners applied automatically
bun scripts/fal-generate.ts "app icon, weather app, sun symbol, flat design, no rounded corners, square edges"
```

- Don't add rounded corners (system applies them)
- Don't add shadows (system applies them)
- Fill entire square—no padding
- Use simple, recognizable symbols

### Android Adaptive Icons

Android uses a two-layer system (foreground + background):

```bash
# Foreground: the icon symbol
bun scripts/fal-generate.ts "app icon foreground, centered symbol, transparent background, safe zone padding"

# Background: solid color or pattern
bun scripts/fal-generate.ts "solid gradient background, blue to purple, square"
```

**Safe zone:** Keep important elements within center 66% (system may mask edges)

### Platform Comparison

| Aspect | iOS | Android |
|--------|-----|---------|
| Corner rounding | Automatic | Varies by launcher |
| Shadows | Automatic | Varies |
| Transparency | Not allowed | Foreground only |
| Background | Part of icon | Separate layer |

## Favicon Best Practices

### Do's

- **Use brand's core visual** (simplified if needed)
- **Test at actual size** before finalizing
- **Ensure contrast** in browser tab context
- **Keep shapes bold** and recognizable

### Don'ts

- **Don't use photos** (unreadable at 16px)
- **Don't include text** (except single letter)
- **Don't use thin lines** (disappear at small sizes)
- **Don't rely on color alone** (test in grayscale)

## Testing Your Icons

### Simulated Preview

```bash
# Create a preview at various sizes
convert icon_master.png \
  \( -clone 0 -resize 16x16 \) \
  \( -clone 0 -resize 32x32 \) \
  \( -clone 0 -resize 64x64 \) \
  +delete -append preview.png
```

### Browser Tab Test

Create an HTML file to test favicon in context:

```html
<!DOCTYPE html>
<html>
<head>
  <link rel="icon" href="favicon.ico">
  <title>Favicon Test</title>
</head>
<body>Check the browser tab</body>
</html>
```

## Common Icon Types

### Letter-based (Logomarks)

```bash
bun scripts/fal-generate.ts "letter G, sans-serif, bold, modern, geometric, app icon style"
```

### Symbol-based

```bash
bun scripts/fal-generate.ts "chat bubble icon, minimal, flat design, app icon"
bun scripts/fal-generate.ts "camera aperture icon, simple, geometric"
```

### Abstract

```bash
bun scripts/fal-generate.ts "abstract flowing shape, modern, dynamic, app icon"
bun scripts/fal-generate.ts "three overlapping circles, flat design, colorful"
```

## Format Conversion

```bash
# PNG to ICO (multi-size)
convert icon-16.png icon-32.png icon-48.png favicon.ico

# PNG to SVG (for scalable icons)
# Note: Requires tracing, not direct conversion
potrace icon.png -s -o icon.svg

# Optimize PNG file size
pngquant --quality=65-80 icon.png -o icon-optimized.png
```
