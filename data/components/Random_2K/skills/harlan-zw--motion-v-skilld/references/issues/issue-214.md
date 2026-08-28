---
number: 214
title: Not working useMotionValueEvent with AnimationComplete
type: other
state: open
created: 2025-10-26
url: "https://github.com/motiondivision/motion-vue/issues/214"
reactions: 0
comments: 1
---

# Not working useMotionValueEvent with AnimationComplete

I have a component with the following `script setup`:
```
const x = useSpring( 0, { duration: 500 } )
useMotionValueEvent( x, 'animationComplete', () => console.log( 'animation completed' ) )
useMotionValueEvent( x, 'change', () => console.log( 'value changed' ) )

onMounted( () => {
  let timeout = setInterval( () => x.set( x.get() - 30 ), 2000 )
} )
```

The component looks like this:
```
<motion.div :style='{ x }'>
...  // children divs
</motion.div>
```

So, (in this simplified example) I want to shift a div every 2 seconds for 30px to the left and want to trigger later on stuff based on the complete status of the animation, before the animation again starts triggered by the `setInterval` function.

...