# Mockups

Generate realistic product mockups, device screenshots, and presentation visuals.

**Model selection:** Use quality models for photorealistic mockups. For UI mockups, style consistency matters more than photorealism. See [models.md](models.md) for discovery.

## Mockup Types

### Device Mockups

Showcase apps and websites on realistic devices:

```bash
# Phone mockup
bun scripts/fal-generate.ts "iPhone placed on wooden desk, screen showing app interface, soft natural lighting, shallow depth of field, lifestyle setting" --size landscape_4_3

# Laptop mockup  
bun scripts/fal-generate.ts "MacBook on marble table, coffee shop background, screen displaying website, morning light through window" --size landscape_16_9

# Multiple devices
bun scripts/fal-generate.ts "laptop and phone side by side on desk, responsive design showcase, clean modern office" --size landscape_16_9
```

**Device prompt tips:**
- Specify device type but avoid exact model names (licensing)
- Describe the screen content conceptually: "displaying a travel app", "showing a dashboard"
- Include environment for context

### Product Mockups

Merchandise and physical products:

```bash
# Apparel
bun scripts/fal-generate.ts "white t-shirt on wooden hanger, front view, neutral background, soft studio lighting, showing logo design placement"

# Packaging
bun scripts/fal-generate.ts "coffee bag mockup on marble counter, artisan cafe setting, morning light, premium packaging design"

# Stationery
bun scripts/fal-generate.ts "business cards fanned out on dark surface, gold foil accents visible, elegant minimal design"
```

### Print Mockups

Posters, books, and print materials:

```bash
# Poster
bun scripts/fal-generate.ts "framed poster on white wall, gallery setting, A2 size, minimalist frame, natural lighting"

# Book
bun scripts/fal-generate.ts "hardcover book standing on wooden shelf, spine visible, library setting, soft focus background"

# Magazine
bun scripts/fal-generate.ts "magazine spread open on coffee table, lifestyle interior, overhead view, natural light"
```

## Prompt Structure for Mockups

```
[Product] + [Placement/Surface] + [Environment] + [Lighting] + [Camera/Focus] + [Mood]
```

**Example breakdown:**
```bash
bun scripts/fal-generate.ts "
  smartphone                    # Product
  placed on wooden table        # Placement
  outdoors during golden hour   # Environment
  soft natural lighting         # Lighting
  shallow depth of field        # Camera
  adventurous travel theme      # Mood
"
```

## Environment Settings

| Setting | Keywords | Best For |
|---------|----------|----------|
| Studio | "white backdrop", "studio lighting", "clean", "product photography" | E-commerce, clean presentations |
| Lifestyle | "coffee shop", "home office", "kitchen counter", "cozy setting" | Relatable context, marketing |
| Outdoor | "park bench", "urban street", "beach", "nature setting" | Adventure, lifestyle brands |
| Office | "modern desk", "meeting room", "workspace" | B2B, professional products |
| Minimal | "solid background", "floating", "isolated" | Focus on product only |

## Lighting for Mockups

Lighting sells the realism:

```bash
# Studio (clean)
bun scripts/fal-generate.ts "product on white surface, even studio lighting, soft shadows, commercial photography"

# Natural (lifestyle)
bun scripts/fal-generate.ts "product by window, natural daylight, soft shadows, lifestyle photography"

# Dramatic (premium)
bun scripts/fal-generate.ts "product on dark surface, single spotlight, dramatic shadows, luxury feel"

# Golden hour (warm)
bun scripts/fal-generate.ts "product outdoors, golden hour lighting, warm tones, soft focus background"
```

## Camera & Focus

Control depth and composition:

```bash
# Shallow DOF (background blur)
bun scripts/fal-generate.ts "phone mockup, 85mm lens, shallow depth of field, bokeh background, focus on screen"

# Flat lay (overhead)
bun scripts/fal-generate.ts "desk mockup, overhead view, flat lay arrangement, even lighting"

# Hero shot (dramatic angle)
bun scripts/fal-generate.ts "product, low angle, dramatic perspective, hero shot"
```

## UI/App Mockups

When the screen content matters:

```bash
# Describe interface conceptually
bun scripts/fal-generate.ts "iPhone showing fitness tracking app, colorful dashboard with charts, dark mode interface, on gym equipment"

# Dashboard mockup
bun scripts/fal-generate.ts "laptop displaying analytics dashboard, data visualization, modern SaaS interface, clean office desk"

# Mobile app flow
bun scripts/fal-generate.ts "three phones showing app onboarding screens, side by side, floating on gradient background"
```

**For actual UI screenshots:** Generate mockup environment first, then composite your real screenshots using `--edit`.

## Compositing Real Designs

Two-step workflow for exact screen content:

```bash
# Step 1: Generate mockup with placeholder
bun scripts/fal-generate.ts "iPhone on desk, blank screen, lifestyle setting" --out mockup_base.png

# Step 2: Composite your screenshot
bun scripts/fal-generate.ts "place this app screenshot on the phone screen, match perspective and reflections" \
  --edit mockup_base.png --edit my_app_screenshot.png --out final_mockup.png
```

## Contextual Elements

Add props for storytelling:

```bash
# Tech product with accessories
bun scripts/fal-generate.ts "laptop mockup with coffee cup, notebook, and pen nearby, creative workspace"

# Travel app context
bun scripts/fal-generate.ts "phone showing travel app, surrounded by passport, sunglasses, and map, vacation planning mood"

# Fitness context
bun scripts/fal-generate.ts "smartwatch showing workout stats, gym towel and water bottle nearby, post-workout setting"
```

## Style Consistency

For multiple mockups in a series:

```bash
# Establish base style
bun scripts/fal-generate.ts "phone mockup, warm natural light, wooden surface, minimal props" --out style_ref.png

# Apply to subsequent mockups
bun scripts/fal-generate.ts "tablet mockup, same style as reference, warm natural light, wooden surface" \
  --edit style_ref.png --out tablet_mockup.png
```

## Post-Processing

### Perspective Correction

```bash
# Adjust perspective with ImageMagick
convert mockup.png -distort Perspective '0,0,10,10 640,0,630,5 640,480,635,485 0,480,5,475' corrected.png
```

### Screen Replacement

For precise screen replacement, consider:
1. Generate environment mockup only
2. Use Photoshop/GIMP for exact screen perspective
3. Or use `--edit` with careful prompting

### Batch Generation

```bash
# Generate multiple angles/settings
for setting in "coffee shop" "office desk" "outdoor cafe"; do
  bun scripts/fal-generate.ts "phone mockup on table, $setting setting, natural light" \
    --out "mockup_${setting// /_}.png"
done
```

## Common Mockup Prompts

### E-commerce Product
```
"product floating on white background, soft shadow below, studio lighting, commercial product photography, high detail"
```

### App Store Screenshot
```
"iPhone displaying app interface, solid gradient background, floating at angle, marketing presentation style"
```

### Social Media Preview
```
"laptop and phone showing responsive design, modern desk setup, lifestyle photography, marketing asset"
```

### Packaging
```
"product packaging on textured surface, natural lighting, premium brand aesthetic, minimal composition"
```

## Troubleshooting

| Issue | Cause | Solution |
|-------|-------|----------|
| Screen looks fake | Lighting mismatch | Add "reflections on screen", match environment lighting |
| Product floating | No shadow/grounding | Add "soft shadow below", "resting on surface" |
| Wrong perspective | No camera guidance | Specify angle: "front view", "3/4 angle", "overhead" |
| Cluttered scene | Too many props | Simplify: "minimal composition", "clean arrangement" |
| Generic look | No mood/context | Add environment details, specify brand aesthetic |
