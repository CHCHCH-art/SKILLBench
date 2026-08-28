# Step-by-Step Migration Checklist

## Pre-Migration

- [ ] Create new git branch: `git checkout -b upgrade-tailwind-v4`
- [ ] Commit all current changes
- [ ] Document current Tailwind version
- [ ] Backup tailwind.config.js
- [ ] Review custom plugins in use
- [ ] Check browser support requirements
- [ ] Note any CSS preprocessor usage

## Phase 1: Dependencies

### Update Package Dependencies

- [ ] Update Tailwind CSS to v4

```bash
npm install tailwindcss@next
```

- [ ] Install appropriate build tool plugin

**For Vite:**

```bash
npm install @tailwindcss/vite
```

**For PostCSS:**

```bash
npm install @tailwindcss/postcss
```

**For CLI:**

```bash
npm install @tailwindcss/cli
```

- [ ] Remove deprecated dependencies

```bash
npm uninstall autoprefixer postcss-import @tailwindcss/container-queries
```

- [ ] Update package.json

```json
{
  "dependencies": {
    "tailwindcss": "^4.0.0"
  },
  "devDependencies": {
    "@tailwindcss/vite": "^4.0.0"
  }
}
```

## Phase 2: Build Configuration

### Vite Configuration

- [ ] Update vite.config.js

```javascript
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import tailwindcss from '@tailwindcss/vite';

export default defineConfig({
  plugins: [react(), tailwindcss()],
});
```

- [ ] Remove PostCSS config if using Vite plugin
- [ ] Test build: `npm run build`

### PostCSS Configuration

- [ ] Update postcss.config.js

```javascript
export default {
  plugins: {
    '@tailwindcss/postcss': {},
  },
};
```

- [ ] Remove autoprefixer and postcss-import
- [ ] Test build: `npm run build`

### Next.js Configuration

- [ ] Ensure postcss.config.js exists

```javascript
export default {
  plugins: {
    '@tailwindcss/postcss': {},
  },
};
```

- [ ] Test: `npm run dev`

## Phase 3: CSS Configuration

### Migrate tailwind.config.js to @theme

- [ ] Open tailwind.config.js
- [ ] Open main CSS file (e.g., src/index.css)
- [ ] Replace @tailwind directives

**Old:**

```css
@tailwind base;
@tailwind components;
@tailwind utilities;
```

**New:**

```css
@import 'tailwindcss';
```

- [ ] Convert theme.extend to @theme

**Example conversion:**

**tailwind.config.js:**

```javascript
module.exports = {
  theme: {
    extend: {
      colors: {
        brand: '#3b82f6',
        accent: '#a855f7',
      },
      fontFamily: {
        sans: ['Inter', 'sans-serif'],
      },
      spacing: {
        18: '4.5rem',
      },
    },
  },
};
```

**CSS:**

```css
@import 'tailwindcss';

@theme {
  --font-sans: 'Inter', sans-serif;
  --color-brand: oklch(0.65 0.25 270);
  --color-accent: oklch(0.65 0.25 320);
  --spacing-18: 4.5rem;
}
```

- [ ] Convert hex colors to oklch() using https://oklch.com/
- [ ] Test: colors render correctly

### Content Detection

- [ ] Remove content array (automatic detection)
- [ ] Add @source directives if needed

```css
@source "../packages/ui";
@source not "./legacy";
```

- [ ] Verify all template files are detected
- [ ] Check .gitignore excludes node_modules

### Custom CSS

- [ ] Migrate @layer components to CSS

```css
@layer components {
  .btn {
    padding: var(--spacing-2) var(--spacing-4);
    background: var(--color-blue-600);
    border-radius: var(--radius-md);
  }
}
```

- [ ] Convert @layer utilities to @utility

**Old:**

```css
@layer utilities {
  .content-auto {
    content-visibility: auto;
  }
}
```

**New:**

```css
@utility content-auto {
  content-visibility: auto;
}
```

## Phase 4: Utility Class Updates

### Opacity Modifiers

- [ ] Search for opacity utilities

```bash
grep -r "bg-opacity-" src/
grep -r "text-opacity-" src/
grep -r "border-opacity-" src/
grep -r "ring-opacity-" src/
```

- [ ] Replace with slash syntax

**Find and replace:**

- `bg-{color} bg-opacity-{value}` → `bg-{color}/{value}`
- `text-{color} text-opacity-{value}` → `text-{color}/{value}`
- `border-{color} border-opacity-{value}` → `border-{color}/{value}`

**Example:**

```html
<div class="bg-black bg-opacity-50"></div>
→
<div class="bg-black/50"></div>
```

- [ ] Test: opacity values render correctly

### Flex Utilities

- [ ] Search for flex utilities

```bash
grep -r "flex-shrink" src/
grep -r "flex-grow" src/
```

- [ ] Replace with new names

**Find and replace:**

- `flex-shrink-0` → `shrink-0`
- `flex-shrink` → `shrink`
- `flex-grow-0` → `grow-0`
- `flex-grow` → `grow`

### Shadow Utilities

- [ ] Search for shadow-sm

```bash
grep -r "shadow-sm" src/
```

- [ ] Replace with shadow-xs

```
shadow-sm → shadow-xs
```

### Ring Utilities

- [ ] Search for bare `ring` class

```bash
grep -r 'class="[^"]*ring[^-"]' src/
```

- [ ] Add explicit width if expecting 3px default

```html
<input class="ring" />
→
<input class="ring-3" />
```

### Border Utilities

- [ ] Search for bare `border` class

```bash
grep -r 'class="[^"]*border[^-"]' src/
```

- [ ] Add explicit color if expecting gray

```html
<div class="border"></div>
→
<div class="border border-gray-200"></div>
```

## Phase 5: Arbitrary Values

### Space Handling

- [ ] Search for arbitrary values with commas

```bash
grep -r "grid-cols-\[.*,.*\]" src/
```

- [ ] Replace commas with underscores

```html
<div class="grid-cols-[1fr,500px,2fr]"></div>
→
<div class="grid-cols-[1fr_500px_2fr]"></div>
```

## Phase 6: Testing

### Build Tests

- [ ] Run development build: `npm run dev`
- [ ] Check console for errors
- [ ] Verify styles load
- [ ] Run production build: `npm run build`
- [ ] Check build output
- [ ] Test production bundle

### Visual Testing

- [ ] Test home page
- [ ] Test all major pages
- [ ] Check responsive breakpoints
- [ ] Verify dark mode (if used)
- [ ] Test hover states
- [ ] Test focus states
- [ ] Check form inputs
- [ ] Verify buttons
- [ ] Check modals/overlays
- [ ] Test animations

### Component Testing

- [ ] Test each component in isolation
- [ ] Verify colors match
- [ ] Check spacing
- [ ] Test typography
- [ ] Verify shadows and borders
- [ ] Check opacity values

### Browser Testing

- [ ] Safari 16.4+
- [ ] Chrome 111+
- [ ] Firefox 128+
- [ ] Mobile Safari
- [ ] Mobile Chrome

## Phase 7: Cleanup

### Remove Old Files

- [ ] Delete tailwind.config.js
- [ ] Remove old PostCSS config (if using Vite plugin)
- [ ] Clean node_modules

```bash
rm -rf node_modules package-lock.json
npm install
```

### Update Documentation

- [ ] Update README.md
- [ ] Document new setup process
- [ ] Update contribution guide
- [ ] Note new browser requirements

### Code Review

- [ ] Review all changed files
- [ ] Check for missed migrations
- [ ] Verify no broken styles
- [ ] Run linter: `npm run lint`
- [ ] Run tests: `npm test`

## Phase 8: Deploy

### Pre-Deploy Checks

- [ ] All tests passing
- [ ] No console errors
- [ ] Production build successful
- [ ] Visual regression tests pass
- [ ] Performance metrics acceptable

### Deploy

- [ ] Merge PR to main
- [ ] Deploy to staging
- [ ] Test staging environment
- [ ] Deploy to production
- [ ] Monitor for issues

### Post-Deploy

- [ ] Verify production site
- [ ] Check analytics for errors
- [ ] Monitor performance
- [ ] Gather feedback

## Common Issues Checklist

- [ ] Styles not applying → Check @import syntax
- [ ] Build errors → Verify PostCSS/Vite config
- [ ] Colors different → Convert hex to oklch
- [ ] Borders wrong color → Add explicit border color
- [ ] Placeholders wrong → Check preflight changes
- [ ] Buttons wrong cursor → Add cursor-pointer
- [ ] Missing utilities → Check for typos
- [ ] Dark mode broken → Verify class strategy

## Rollback Plan

If migration fails:

- [ ] Revert git branch: `git checkout main`
- [ ] Delete branch: `git branch -D upgrade-tailwind-v4`
- [ ] Reinstall dependencies: `npm install`
- [ ] Document issues encountered
- [ ] Plan remediation

## Success Criteria

- [ ] All pages render correctly
- [ ] No console errors
- [ ] Production build successful
- [ ] All tests passing
- [ ] Performance maintained or improved
- [ ] No visual regressions
- [ ] Browser support verified
- [ ] Documentation updated

## Estimated Timeline

- Pre-migration: 1 hour
- Dependencies & build config: 1-2 hours
- CSS migration: 2-4 hours
- Utility updates: 4-8 hours
- Testing: 4-8 hours
- Cleanup & documentation: 1-2 hours
- Deploy: 1-2 hours

**Total: 14-27 hours** depending on project size
