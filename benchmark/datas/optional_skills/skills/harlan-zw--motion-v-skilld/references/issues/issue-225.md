---
number: 225
title: "List transitions behave differently with display: grid vs flex"
type: other
state: open
created: 2026-01-12
url: "https://github.com/motiondivision/motion-vue/issues/225"
reactions: 0
comments: 2
---

# List transitions behave differently with display: grid vs flex

This may just be a CSS limitation, but I’d appreciate any direction or advice on how to approach this and how to know these kind of things are not related to `motion-v`.

https://github.com/user-attachments/assets/8e7f65f0-5bb9-484d-b3d8-8de2e85c7eeb

### 1. Describe what is happening

I want to display modals in a somewhat unique way: the last opened modal should be on its own, while the rest are stacked on the left. I thought I was being clever by using the stacking “trick” with `display: grid`, but this causes things to look bad when closing the last/right modal. I feel like this should just work, because with `display: flex` everything behaves as expected when closing modals.

...