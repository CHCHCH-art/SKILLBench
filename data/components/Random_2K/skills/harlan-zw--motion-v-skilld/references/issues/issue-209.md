---
number: 209
title: Layout animations stop working after full page reload (F5)
type: other
state: open
created: 2025-10-08
url: "https://github.com/motiondivision/motion-vue/issues/209"
reactions: 0
comments: 0
---

# Layout animations stop working after full page reload (F5)

Hey there 

I'm running into a strange issue with motion-v layout animations and could really use some help figuring out what's going on.
Everything works perfectly while the app is running, but after a full page reload (F5), layout transitions just stop animating.

I’d really appreciate any help or guidance on this - thank you in advance! 

**1. Describe the bug**

Layout animation (layout prop) in motion-v stops working after a full page reload (F5).
It works perfectly when the component is hot-reloaded or re-mounted manually, but not on the first mount after a full reload.

The bug occurs even in a minimal setup using <motion.div layout> inside a Vue component.

**2. Reproduction component**

...