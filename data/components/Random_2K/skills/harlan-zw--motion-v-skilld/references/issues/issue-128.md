---
number: 128
title: No auto import and no completions in JetBrains IDEs
type: other
state: closed
created: 2025-03-24
url: "https://github.com/motiondivision/motion-vue/issues/128"
reactions: 0
comments: 5
---

# No auto import and no completions in JetBrains IDEs

**1. Describe the bug**
Automatic imports and completion in JetBrains work for all components (MotionConfig, AnimatePresence...) except <motion>
Even if I manually import motion, the import is considered as unused and an error appear on the <motion.div> tag.

If I import motion as MotionEl, the import is not considered as unused but I have this error :


**3. Steps to reproduce**

Steps to reproduce the behavior:

1. Open JetBrains IDE (GoLand, WebStorm...)
2. Create empty VueJS + TypeScript project
3. Install motion-v with npm
4. In App.vue, type start typing <motion ...
5. No completion, no type check and an error is visible

**4. Expected behavior**

...