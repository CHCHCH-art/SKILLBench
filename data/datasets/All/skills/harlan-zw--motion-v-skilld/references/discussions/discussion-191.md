---
number: 191
title: "[Vue]: Native dialog element entry/exit animations"
category: Q&A
created: 2025-07-21
url: "https://github.com/motiondivision/motion-vue/discussions/191"
upvotes: 1
comments: 1
answered: false
---

# [Vue]: Native dialog element entry/exit animations

has anyone been able to animate the native dialog element? I have a reactive value 'open' that on change, calls the dialog elements showDialog() or close(). ive gotten as far as animating the entry animation but for the life of me, when exiting, either via a click outside the dialog, a close button inside the dialog or (especially) the esc key, the AnimatePresence and dialog key don't seem to help and it immediately exits. would be great to get more insight into how to use motion-v with top-layer elements

---

## Top Comments

**@rick-hup** [maintainer]:

You'll need to control the dialog's rendering through state so AnimatePresence can catch it. Here's what I mean:

Prevent the default close behavior (@cancel.prevent)
Handle the close through your state (isOpen)
Let AnimatePresence orchestrate the exit animation before actual DOM removal

Here's the official example: https://examples.motion.dev/vue/modal
