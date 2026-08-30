---
number: 42
title: In Vue3.5.13, the route jumps to a new page, and after the drag and drop attribute is enabled, the first time an element is dragged, it will disappear directly
type: other
state: closed
created: 2025-01-15
url: "https://github.com/motiondivision/motion-vue/issues/42"
reactions: 0
comments: 2
---

# In Vue3.5.13, the route jumps to a new page, and after the drag and drop attribute is enabled, the first time an element is dragged, it will disappear directly

**1. Describe the bug**
Operation, route to a new page, drag and drop elements, elements disappear (but in fact, the element's position was not determined, causing it to leave the viewport directly)

**2. Steps to reproduce**

Steps to reproduce the behavior:

1. Jump from a routing page to the target demo page, drag and drop elements, and the elements flash and disappear
2. Refresh the routing page where the element is currently located directly in the browser, drag and drop the element as expected without any errors

