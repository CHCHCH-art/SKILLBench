---
number: 119
title: More examples with Reka UI
category: Q&A
created: 2025-03-18
url: "https://github.com/motiondivision/motion-vue/discussions/119"
upvotes: 1
comments: 2
answered: true
---

# More examples with Reka UI

Hello,

I'm trying to use Motion Vue with Reka UI components (Navigation Menu, Accordion, Dropdown Menu and more) and I'm having a hard time understanding when / where to use AnimatePresence alongside Motion and Reka UI components. Should Motion always be the first descendant of AnimatePresence? Qhen to use the multiple prop?

I find the documentation has a lot of implicit knowledge that is not explained or linked to, so any example with Reka UI would be greatly appreciated! Thanks.

---

## Accepted Answer

**@rick-hup** [maintainer]:

@lewebsimple  In the latest version, the multiple prop has been removed. AnimatePresence now automatically looks for the nearest Motion component to trigger exit animations. However, the component to be removed must be a direct child of AnimatePresence.