---
number: 76
title: Animating children on exit
category: Q&A
created: 2025-02-23
url: "https://github.com/motiondivision/motion-vue/discussions/76"
upvotes: 1
comments: 2
answered: true
---

# Animating children on exit

I have the following structure, is there a way to animate the exit of "B"?

```html
<AnimatePresence>
  <Motion v-if="...">
    A

    <Motion :exit="{...}">
      B
    </Motion>
  </Motion>
</AnimatePresence>
```

---

## Accepted Answer

**@rick-hup** [maintainer]:

you can use `variants` to controle  chidren animation.

```vue
<script setup lang="ts">
import { ref } from 'vue';
import { motion, AnimatePresence } from 'motion-v';
const isShow = ref(true);
</script>

<template>
  <button @click="isShow = !isShow">Toggle</button>
  <AnimatePresence>
    <motion.div
      v-if="isShow"
      initial="hidden"
      animate="visible"
      exit="exit"
      style="width: 200px; height: 200px; background-color: rgb(239, 68, 68)"
    >
      <motion.div
        :variants="{
          hidden: { opacity: 0, y: 100 },
          visible: { opacity: 1, y: 0 },
          exit: { opacity: 0, y: -100 },
        }"
        style="width: 100px; height: 100px; background-color: rgb(68, 114, 239)"
      >
      </motion.div>
    </motion.div>
  </AnimatePresence>
</template>

```

