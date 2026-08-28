---
number: 144
title: "[BUG] Duplicated imports \"LazyMotion\" in Nuxt"
type: other
state: closed
created: 2025-04-06
url: "https://github.com/motiondivision/motion-vue/issues/144"
reactions: 3
comments: 2
---

# [BUG] Duplicated imports "LazyMotion" in Nuxt

**1. Describe the bug**
When motionv nuxt plugin is used together with Nuxt/Icon or Nuxt Content this warning pops up on dev start

**2. IMPORTANT: Provide a CodeSandbox reproduction of the bug**

https://github.com/ThimoDEV/nuxt-motion-v-duplicate-bug

**3. Steps to reproduce**

Steps to reproduce the behavior:

- Create a fresh Nuxt project
- Install motion-v-nuxt module and Nuxt Icon and/or Nuxt content module (one of the two is enough)
- Run dev
- See auto import warning: Duplicated imports "LazyMotion", the one from "motion-v?nuxt_component=async&nuxt_component_name=Motion&nuxt_component_export=Motion" has been ignored and "motion-v" is used

**4. Expected behavior**

I expect no duplicate import warning

**5. Video or screenshots**

**6. Environment details**

...

---

## Top Comments

**@rick-hup** [maintainer] (+2):

I see the issue - LazyMotion component is being treated as an async Motion component. may need to remove LazyMotion from auto-import to fix this conflict.

**@StirStudios**:

@ThimoDEV same for us as well.