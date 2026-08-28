---
number: 143
title: layoutId not working when keepalive used for pages
type: other
state: closed
created: 2025-04-04
url: "https://github.com/motiondivision/motion-vue/issues/143"
reactions: 0
comments: 1
---

# layoutId not working when keepalive used for pages

**1. Describe the bug**
shared layout is not working when `keepalive` is used. In this sandbox I put the keepalive inside `nuxt.config.ts`

**2. IMPORTANT: Provide a CodeSandbox reproduction of the bug**
https://codesandbox.io/p/devbox/wrv4vx

**3. Steps to reproduce**

1. Use keepalive for router, In this case enable `keepalive` for `NuxtPage`


**6. Environment details**

```
"devDependencies": {
  "nuxt": "^3.10.0",
  "vue": "^3.4.20",
  "vue-router": "^4.3.0"
},
"dependencies": {
  "motion-v": "^1.0.0-beta.1"
}
```
