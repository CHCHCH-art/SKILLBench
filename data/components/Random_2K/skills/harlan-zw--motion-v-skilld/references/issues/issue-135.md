---
number: 135
title: `motion-v` Vite error
type: other
state: closed
created: 2025-04-01
url: "https://github.com/motiondivision/motion-vue/issues/135"
reactions: 3
comments: 9
---

# `motion-v` Vite error

**1. Describe the bug**
Adding `motion-v` to my project (replacing `motion`) results in this error:

...

---

## Top Comments

**@pedromelo222** (+6):

I applied this temporary fix to allow the build to proceed.

Add the following to your package.json:

For pnpm:

`"pnpm": {
  "overrides": {
    "motion-dom": "12.6.1"
  }
}`

npm: 

`"overrides": {
  "motion-dom": "12.6.1"
}`


**@StirStudios** (+4):

@rick-hup thanks for the speed resolve. Works like a charm!

**@rick-hup** [maintainer]:

Are you installing both 'motion' and 'motion-v'?