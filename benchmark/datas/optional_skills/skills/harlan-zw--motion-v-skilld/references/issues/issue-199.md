---
number: 199
title: Type inconsistency in layoutDependency prop
type: other
state: closed
created: 2025-08-29
url: "https://github.com/motiondivision/motion-vue/issues/199"
reactions: 0
comments: 1
---

# Type inconsistency in layoutDependency prop

See https://github.com/motiondivision/motion-vue/blob/5b8eabd65972ccb86d0be4e32801d7b2a64c1ee9/packages/motion/src/components/motion/props.ts#L55

The docs suggest that this property could be a boolean, but that is not wat the type declaration states.

Using a boolean results in a warning in the console.

Suggestion: make `layoutDependency` an 'any' type to align with https://github.com/motiondivision/motion/blob/c084ec07b483c00dce197e8958f9cf30bd493268/packages/motion-dom/src/node/types.ts#L942l and clarify the docs about the expected value.