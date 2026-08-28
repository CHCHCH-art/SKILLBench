---
number: 70
title: Animating exit of Radix Popover
category: Q&A
created: 2025-02-15
url: "https://github.com/motiondivision/motion-vue/discussions/70"
upvotes: 1
comments: 1
answered: true
---

# Animating exit of Radix Popover

Hello! I'm trying to animate a Radix Popover with Motion Vue, and it's working perfectly when opening it, but not when closing it.  

I got the following component:
```vue
<script setup lang="ts">
import { Popover } from 'radix-vue/namespaced';
import { AnimatePresence, Motion } from 'motion-v';
</script>

<template>
  <div class="px-4">
    <Popover.Root>
      <Popover.Trigger class="cursor-pointer">
        Toggle popover
      </Popover.Trigger>
      
      <Popover.Portal>
        <AnimatePresence>
          <Popover.Content as-child class="px-4 py-2 bg-pink-400">
              <Motion
              :initial="{ opacity: 0, scale: 0.95 }"
              :animate="{ opacity: 1, scale: 1 }"
              :exit="{ opacity: 0, scale: 0.95 }"
              :transition="{ duration: 0.3, ease: 'easeInOut' }"
            >
              I'm a popover!
            </Motion>
          </Popover.Content>
        </AnimatePresence>
      </Popover.Portal>
    </Popover.Root>
  </div>
</template>
```...

---

## Accepted Answer

**@rick-hup** [maintainer]:

Currently, to implement exit animations, you might need to structure your code like this:
```vue
<script setup lang="ts">
import { AnimatePresence, Motion } from 'motion-v'
import { Popover } from 'reka-ui/namespaced'

const open = ref(false)
</script>

<template>
  <div class="px-4">
    <Popover.Root v-model:open="open">
      <Popover.Trigger class="cursor-pointer">
        Toggle popover
      </Popover.Trigger>

      <Popover.Portal>
        <Popover.Content
          as-child
          class="px-4 py-2 bg-pink-400"
          :force-mount="true"
        >
          <AnimatePresence>
            <Motion
              v-if="open"
              :initial="{ opacity: 0, scale: 0.95 }"
              :animate="{ opacity: 1, scale: 1 }"
              :exit="{ opacity: 0, scale: 0.95 }"
              :transition="{ duration: 0.3, ease: 'easeInOut' }"
            >
              I'm a popover!
            </Motion>
          </AnimatePresence>
        </Popover.Content>
      </Popover.Portal>
    </Popover.Root>
  </div>
</template>
```...