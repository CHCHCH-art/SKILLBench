# Complete Breaking Changes List

## Configuration System

### JavaScript → CSS Configuration

**Breaking:** No more `tailwind.config.js` file.

**v3:**

```javascript
module.exports = {
  theme: {
    extend: {
      colors: { brand: '#3b82f6' },
    },
  },
};
```

**v4:**

```css
@theme {
  --color-brand: oklch(0.65 0.25 270);
}
```

**Impact:** All theme customization moves to CSS.

### Content Detection

**Breaking:** No manual content array needed.

**v3:**

```javascript
content: ['./src/**/*.{html,js}']
```

**v4:**

Automatic detection. Manual control via `@source` if needed.

**Impact:** Simplified setup, but less explicit control.

## Import Directives

### @tailwind → @import

**Breaking:** Different import syntax.

**v3:**

```css
@tailwind base;
@tailwind components;
@tailwind utilities;
```

**v4:**

```css
@import 'tailwindcss';
```

**Impact:** All templates need updating.

## Utility Class Changes

### Opacity Modifiers Removed

**Breaking:** Separate opacity utilities removed.

**v3:**

```html
<div class="bg-black bg-opacity-50"></div>
<div class="text-gray-900 text-opacity-75"></div>
<div class="border-blue-500 border-opacity-60"></div>
<div class="ring-blue-500 ring-opacity-30"></div>
```

**v4:**

```html
<div class="bg-black/50"></div>
<div class="text-gray-900/75"></div>
<div class="border-blue-500/60"></div>
<div class="ring-blue-500/30"></div>
```

**Impact:** Search and replace needed across entire codebase.

**Automated fix:**

```bash
find . -name "*.html" -o -name "*.jsx" -o -name "*.tsx" | xargs sed -i '' 's/bg-\([a-z-]*\) bg-opacity-\([0-9]*\)/bg-\1\/\2/g'
```

### Flex Utility Renames

**Breaking:** Utility names changed.

**v3:**

```html
<div class="flex-shrink-0"></div>
<div class="flex-shrink"></div>
<div class="flex-grow-0"></div>
<div class="flex-grow"></div>
```

**v4:**

```html
<div class="shrink-0"></div>
<div class="shrink"></div>
<div class="grow-0"></div>
<div class="grow"></div>
```

**Impact:** All flex utilities need renaming.

### Shadow Utility Rename

**Breaking:** Smallest shadow renamed.

**v3:**

```html
<div class="shadow-sm"></div>
```

**v4:**

```html
<div class="shadow-xs"></div>
```

**Impact:** Update all uses of `shadow-sm`.

### Ring Default Width

**Breaking:** Default ring width changed.

**v3:**

```html
<input class="ring" />
```

Ring width: 3px

**v4:**

```html
<input class="ring" />
```

Ring width: 1px

**Fix for v3 behavior:**

```html
<input class="ring-3" />
```

**Impact:** All bare `ring` utilities render thinner.

## Color System

### Default Border Color

**Breaking:** Border color changed from gray to currentColor.

**v3:**

```html
<div class="border"></div>
```

Border color: gray-200

**v4:**

```html
<div class="border"></div>
```

Border color: currentColor (inherits text color)

**Fix for v3 behavior:**

```html
<div class="border border-gray-200"></div>
```

**Impact:** Borders may appear different colors.

### Default Ring Color

**Breaking:** Ring color changed from blue to currentColor.

**v3:**

```html
<input class="ring" />
```

Ring color: blue-500

**v4:**

```html
<input class="ring" />
```

Ring color: currentColor

**Fix for v3 behavior:**

```html
<input class="ring ring-blue-500" />
```

**Impact:** Rings inherit text color.

### OkLCh Color Space

**Breaking:** Color values use OkLCh instead of RGB.

**v3:**

```javascript
colors: {
  brand: '#3b82f6',
}
```

**v4:**

```css
@theme {
  --color-brand: oklch(0.65 0.25 270);
}
```

**Impact:** Custom colors need conversion. Colors may look slightly different (more vivid on modern displays).

## PostCSS Changes

### Plugin Name

**Breaking:** Different PostCSS plugin.

**v3:**

```javascript
plugins: {
  'tailwindcss': {},
  'autoprefixer': {},
}
```

**v4:**

```javascript
plugins: {
  '@tailwindcss/postcss': {},
}
```

**Impact:** PostCSS config needs updating. Remove `autoprefixer` and `postcss-import` (no longer needed).

## Preflight Changes

### Placeholder Color

**Breaking:** Placeholder text color changed.

**v3:**

```css
::placeholder {
  color: theme('colors.gray.400');
}
```

**v4:**

```css
::placeholder {
  color: currentColor;
  opacity: 0.5;
}
```

**Impact:** Placeholders inherit text color at 50% opacity.

**Fix for v3 behavior:**

```css
@layer base {
  ::placeholder {
    color: theme('colors.gray.400');
    opacity: 1;
  }
}
```

### Button Cursor

**Breaking:** Button cursor changed.

**v3:**

```css
button {
  cursor: pointer;
}
```

**v4:**

```css
button {
  cursor: default;
}
```

**Impact:** Buttons no longer show pointer cursor by default.

**Fix for v3 behavior:**

```css
@layer base {
  button {
    cursor: pointer;
  }
}
```

Or add explicit classes:

```html
<button class="cursor-pointer">Click me</button>
```

## Arbitrary Values

### Space Handling

**Breaking:** Spaces in arbitrary values use underscores.

**v3:**

```html
<div class="grid-cols-[1fr,500px,2fr]"></div>
```

**v4:**

```html
<div class="grid-cols-[1fr_500px_2fr]"></div>
```

**Impact:** All arbitrary values with commas need updating.

## Browser Support

### Minimum Versions

**Breaking:** Dropped support for older browsers.

**v3:**

- IE 11+
- Safari 10+
- Chrome 60+

**v4:**

- Safari 16.4+
- Chrome 111+
- Firefox 128+

**Impact:** Projects requiring older browser support cannot upgrade.

## CSS Preprocessors

### No Sass/Less/Stylus Support

**Breaking:** Incompatible with CSS preprocessors.

**v3:**

Can use with Sass, Less, Stylus

**v4:**

Cannot use CSS preprocessors (Tailwind functions as preprocessing layer)

**Impact:** Remove CSS preprocessors from build pipeline.

## Plugin System

### Plugin API Changes

**Breaking:** Plugin API completely rewritten.

**v3 plugin:**

```javascript
const plugin = require('tailwindcss/plugin');

module.exports = plugin(function ({ addUtilities, theme }) {
  addUtilities({
    '.content-auto': {
      'content-visibility': 'auto',
    },
  });
});
```

**v4 equivalent:**

```css
@utility content-auto {
  content-visibility: auto;
}
```

**Impact:** All custom plugins need manual rewrite.

## @apply Restrictions

### Limited @apply Support

**Breaking:** @apply only works for small subset of utilities.

**v3:**

```css
.btn {
  @apply px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700;
}
```

**v4:**

@apply has limited support. Use @utility instead:

```css
@utility btn {
  padding: var(--spacing-2) var(--spacing-4);
  background: var(--color-blue-600);
  color: var(--color-white);
  border-radius: var(--radius-md);
}
```

**Impact:** Many @apply patterns need refactoring.

## Mobile Hover Behavior

### Hover on Touch Devices

**Breaking:** Hover styles don't apply on touch devices.

**v3:**

Hover styles triggered on tap

**v4:**

Hover styles only on devices supporting hover

**Impact:** Touch devices won't show hover states (improves UX).

## Container Plugin

### Built-in Container Queries

**Breaking:** Container queries plugin no longer needed.

**v3:**

```javascript
plugins: [require('@tailwindcss/container-queries')]
```

**v4:**

Built-in. No plugin needed.

**Impact:** Remove plugin dependency. Syntax remains same.

## Summary Table

| Change | v3 | v4 | Impact |
|--------|----|----|--------|
| Config | tailwind.config.js | @theme | High |
| Import | @tailwind | @import | High |
| Opacity | bg-opacity-50 | bg-{color}/50 | High |
| Flex | flex-shrink | shrink | Medium |
| Shadow | shadow-sm | shadow-xs | Low |
| Ring width | 3px | 1px | Medium |
| Border color | gray-200 | currentColor | Medium |
| Color space | RGB | OkLCh | Medium |
| PostCSS | tailwindcss | @tailwindcss/postcss | High |
| Placeholder | gray-400 | currentColor/50 | Low |
| Button cursor | pointer | default | Low |
| Browsers | IE 11+ | Safari 16.4+ | High |
| Preprocessors | Supported | Not supported | High |
| Plugins | JS API | CSS @utility | High |
