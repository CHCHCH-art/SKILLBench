---
number: 156
title: Does Motion-Vue only work with Composition API?
category: Q&A
created: 2025-04-24
url: "https://github.com/motiondivision/motion-vue/discussions/156"
upvotes: 1
comments: 1
answered: true
---

# Does Motion-Vue only work with Composition API?

I have no issues importing and using `<motion.div>` when I'm in a Composition API component, but as soon as I drop it into an Options API component I get the following error:

```
Failed to resolve component: motion.div
If this is a native custom element, make sure to exclude it from component resolution via compilerOptions.isCustomElement.
```

Is this expected or am I possibly doing something wrong?

---

## Accepted Answer

**@rick-hup** [maintainer]:

hey @jackmcdade! For Options API components, it's recommended to use Motion Primitive 