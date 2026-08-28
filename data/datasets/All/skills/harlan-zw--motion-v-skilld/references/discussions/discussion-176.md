---
number: 176
title: Combining whileHover with whileInView
category: Q&A
created: 2025-06-24
url: "https://github.com/motiondivision/motion-vue/discussions/176"
upvotes: 1
comments: 1
answered: true
---

# Combining whileHover with whileInView

I'm having some trouble with combining different animation states. I have a button that I want to animate in as soon as it comes into view. But I also want to animate it on hover. But somehow **the opacity of the button does not update when I toggle the disabled state** of the button. Any idea what would be the right way to do this? Here's a link to a codesandbox and here's my component:

```vue
<motion.button
    :variants="{
      initial: { y: 20, opacity: 0 },
      visible: { y: 0, opacity: 1 },
      'visible-disabled': { y: 0, opacity: 0.25 },
      hovered: { scale: 1.5 },
    }"
    :disabled="disabled"
    initial="initial"
    :whileHover="'hovered'"
    :whileInView="disabled ? 'visible-disabled' : 'visible'"
>CLICK ME</motion.button>
  ```...

---

## Accepted Answer

**@rick-hup** [maintainer]:

@thomasjonas this is a bug. You can report an issue for this.