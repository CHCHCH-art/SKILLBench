---
number: 164
title: Animate Mini in Vue
category: Q&A
created: 2025-05-19
url: "https://github.com/motiondivision/motion-vue/discussions/164"
upvotes: 2
comments: 1
answered: true
---

# Animate Mini in Vue

Hi there,

I can't see anywhere in the Vue docs how to use Animate Mini...

> The animate() function is a powerful tool for creating and controlling animations.
>
> animate("li", { opacity: 0 })
> It comes in two sizes, mini (2.3kb) and hybrid (18kb).
>
>The mini version can animate HTML and SVG styles using native browser APIs for incredible performance.

Does anybody know how to enable this in the Vue version

---

## Accepted Answer

**@rick-hup** [maintainer]:

@gilesbutler 
```
import { animateMini } from 'motion-v'
```