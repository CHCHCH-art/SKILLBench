---
number: 188
title: The flash problem of animation and the inability to control through v-show?
category: Q&A
created: 2025-07-11
url: "https://github.com/motiondivision/motion-vue/discussions/188"
upvotes: 1
comments: 2
answered: true
---

# The flash problem of animation and the inability to control through v-show?

Minimum implementation: 
https://stackblitz.com/edit/nuxt-starter-yrsjqtcp?file=app.vue

Question:
1. When the element is controlled through v-show and is not wrapped with the AnimatePresence component, why does its animation effect not take effect?
2. When the element is controlled by v-if and wrapped by the AnimatePresence component, if the element is activated again before the exit animation (exit state) is completed, why does the exit animation state that has never been executed flash to initial and then transition to animate state? How to solve it?

---

## Accepted Answer

**@rick-hup** [maintainer]:

1. If you want v-show to trigger animations, you need to wrap it with AnimatePresence, otherwise it cannot intercept Vue's DOM setting of display:none.
2. When v-if is false, the corresponding component will unmount. During its exit animation, if v-if=true, it's actually a new node entering. You can use v-show (component won't be unmounted).