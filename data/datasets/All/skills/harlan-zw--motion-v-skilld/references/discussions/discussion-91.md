---
number: 91
title: useInView Always Returns false?!
category: Q&A
created: 2025-03-03
url: "https://github.com/motiondivision/motion-vue/discussions/91"
upvotes: 1
comments: 1
answered: true
---

# useInView Always Returns false?!

The `useInView` composable from `motion-v` is not detecting when the referenced element enters the viewport. The value of `isScopeInView` remains `false` at all times.

```vue
<template>
  isScopeInView: {{ isScopeInView }}
  <Motion
    as="section"
    ref="scopeRef"
    class="bg-gray-100 py-20"
    :initial="{ opacity: 0, y: 50 }"
    :animate="isScopeInView ? { opacity: 1, y: 0 } : { opacity: 0, y: 50 }"
    :transition="{ duration: 0.8, ease: 'easeOut' }"
  >
    <h2 class="pb-20 text-center text-3xl font-bold text-gray-800">Hi</h2>
  </Motion>
</template>

<script setup lang="ts">
import { Motion, useInView } from 'motion-v';
import { ref } from 'vue';
import type { Ref } from 'vue';

const scopeRef = ref<HTMLElement | null>(null);
const isScopeInView = useInView(scopeRef as Ref<HTMLElement>);
</script>
```...

---

## Accepted Answer

**@rick-hup** [maintainer]:

Actually, scopeRef gets the Motion instance, not an HTMLElement. You can use useDomRef to get the DOM element instead:
```jsx
import { useDomRef } from 'motion-v';
const scopeRef = useDomRef();
<Motion
    ref="scopeRef"
>
</Motion>
```