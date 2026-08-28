---
number: 232
title: Cannot set properties of undefined (setting 'done')
type: other
state: open
created: 2026-02-10
url: "https://github.com/motiondivision/motion-vue/issues/232"
reactions: 0
comments: 0
---

# Cannot set properties of undefined (setting 'done')

**1. Describe the bug**
In 1.10.2, I'm getting a race condition error with AnimatePresence usage surrounding a single v-if Motion child that didn't exist in 1.9.0 .

`Cannot set properties of undefined (setting 'done')`

*** **_Downgrading from 1.10.2 to 1.9.0 resolves the issue for me._** ***

**2. IMPORTANT: Provide a CodeSandbox reproduction of the bug**

I _couldn't_ recreate this in a CodeSandbox, at least with a very simple reproduction.

**3. Steps to reproduce**

This isn't helpful, but in my case, I'm simply doing
```
<AnimatePresence>
    <Motion v-if="tokenLoadingDebounced" :animate="{ opacity: 1 }" :exit="{ opacity: 0 }" key="tokenLoading">
      <Icon icon="tabler:loader" class="size-7 animate-spin text-gray-400" />
    </Motion>
</AnimatePresence>
```

...