---
number: 178
title: "Can not make :whileInView have a dynamic variant"
type: other
state: closed
created: 2025-06-25
url: "https://github.com/motiondivision/motion-vue/issues/178"
reactions: 0
comments: 0
---

# Can not make :whileInView have a dynamic variant

**1. Describe the bug**
A motion component does not re-evaluate or update its animation when the value of :whileInView changes due to a reactive state This results in stale animation behavior even though the reactive condition behind whileInView has changed. (Also see https://github.com/motiondivision/motion-vue/discussions/176)

**2. IMPORTANT: Provide a CodeSandbox reproduction of the bug**
CodeSandbox: https://codesandbox.io/p/devbox/d5f524

**3. Steps to reproduce**

In the CodeSandbox example:

...