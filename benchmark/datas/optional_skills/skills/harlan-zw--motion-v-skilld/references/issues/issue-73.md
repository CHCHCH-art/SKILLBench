---
number: 73
title: `FeatureManager` improvement
type: other
state: closed
created: 2025-02-19
url: "https://github.com/motiondivision/motion-vue/issues/73"
reactions: 1
comments: 1
---

# `FeatureManager` improvement

At this moment `FeatureManager` enables all features even if they aren't used by `Motion`. It leads to overhead and unwanted side effects. Most noticeable one is `PressGesture` feature uses `press` which sets `tabindex` to 0.

There is `isActive` method in most of the features, but as i can see `FeatureManager` ignores it. Would be nice to push this idea further.