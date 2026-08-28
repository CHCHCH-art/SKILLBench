---
number: 169
title: "[BUG] Scroll progress immediately jumps to 1 when target has a fixed height."
type: other
state: open
created: 2025-06-04
url: "https://github.com/motiondivision/motion-vue/issues/169"
reactions: 0
comments: 1
---

# [BUG] Scroll progress immediately jumps to 1 when target has a fixed height.

**1. Describe the bug**
When using `useScroll` target option with an element that has a fixed height (1000px for example), the scroll progress immediately jumps to 1.

After this, when I scroll down the progress goes from 1 to 0 and when going up from 0 to 1. 

If I apply a height of 100vh then this doesn't happen.

**2. IMPORTANT: Provide a CodeSandbox reproduction of the bug**

https://codesandbox.io/p/devbox/3lj26q

**3. Steps to reproduce**

Steps to reproduce the behavior:

1. Go to https://codesandbox.io/p/devbox/3lj26q
2. Open console
3. Load the page
4. See progress log

**4. Expected behavior**

I'd expect that it behaves the same weather is a fixed height or vh height

