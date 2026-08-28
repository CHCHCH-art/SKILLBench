---
number: 155
title: How to do staggered animations without variants?
type: other
state: open
created: 2025-04-24
url: "https://github.com/motiondivision/motion-vue/issues/155"
reactions: 0
comments: 4
---

# How to do staggered animations without variants?

I am trying to understand how staggered animations would work without variants. To me it is hard to understand why `<AnimationPresence>` is needed in the first place and why exit animations doesnt work without it. But then, within nested animations, do I need multiple `<AnimationPresence>` or just one?

For example, this staggered animation works for enter but not for exit:

```vue
<template>
   <AnimatePresence>
        <motion.ul v-if="isVisible">
            <motion.li v-for="index in 5"
                       :key="index"
                       :initial="{ opacity: 0 }"
                       :animate="{ opacity: 1, transition: { delay: index * 0.05 } }"
                       :exit="{ opacity: 0, transition: { delay: (5-index) * 0.05 } }"
            >
              {{ index }}
            </motion.li>
        </motion.ul>
   </AnimatePresence>
<template>
```...