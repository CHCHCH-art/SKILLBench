---
number: 165
title: Not compatible with vue-router?
category: Q&A
created: 2025-05-19
url: "https://github.com/motiondivision/motion-vue/discussions/165"
upvotes: 1
comments: 0
answered: false
---

# Not compatible with vue-router?

Migrating from vueuse/motion where I was able to do:

```vue
<router-view v-motion :initial="{blah}" :enter="{blah}">
```

to add a transition whenever the route changed.

Following the docs here: https://github.com/motiondivision/motion-vue/issues/149, I've attempted to use `:as`, `as-child`, and `motion.create`, but none work.

e.g.

```vue
const MotionRouterView = motion.create(RouterView)
```
or
```vue
<motion :initial="{blah}" :animate="{blah}" as-child>
    <router-view></router-view>
</motion>
```

Am I doing something wrong, or are those router components just fundamentally incompatible?