# Design notes — open items to revisit during implementation

Running notes on visual/interaction direction that exceed what the current prototyping tool can validate. These are bar-setting notes, not specs — revisit once we're in code with real tooling.

## Splash / onboarding background — "liquid glass"

**Direction:** A full-screen, continuously morphing liquid/glass form (crystal-ball quality — think the ChatGPT voice-mode orb, filtered through Apple's Liquid Glass material language) that persists as the background through the entire onboarding sequence (welcome → privacy → permissions → home), so onboarding feels like *already being inside the space* rather than a loading screen before the app starts.

**The gap:** What's been prototyped so far (a morphing blob with an inner glint, flat fills, no blur) gets the *motion* roughly right but not the *material*. The actual bar is real translucency, blur/refraction, and specular highlight — the thing that makes Liquid Glass feel like glass and not just a moving shape. The mockup tool used for these prototypes explicitly disallows blur, gradients, and glow (flat-design constraint), so it cannot validate whether the material quality hits the bar. **This needs dedicated craft time with real tooling before being considered settled** — don't treat the current mockups as more than motion sketches.

**Likely directions to prototype once in code:**
- SwiftUI's native Liquid Glass APIs (`.glassEffect`, `UIVisualEffectView` materials/vibrancy) — the "real" version of this material on iOS.
- Custom shaders (Metal / SwiftUI `Canvas` + `TimelineView`) if native materials don't give enough control over the morphing behavior.

## Touch interaction — reacts like water

**Direction:** The background shouldn't just parallax toward a cursor — touching it should feel like touching water or a liquid/gel material: a localized ripple or displacement that propagates outward from the touch point and settles, on top of (or interacting with) the ambient morphing motion.

**The gap:** Current prototype only does global parallax (the whole shape drifts toward the pointer). A real ripple/displacement response is a different category of effect — likely needs a fluid-sim approximation or displacement shader, not just transform offsets.

**Likely directions to prototype once in code:**
- Shader-based displacement (Metal/SwiftUI) driven by touch position + velocity, with decay over time.
- Look at existing fluid-simulation-on-touch references (common in creative-coding/shader communities) for the math, adapted to a glass-material look rather than literal water.

## Status

Flagged, not blocking. Revisit when we move from brainstorming/mockups into actual app code, where we'll have access to real rendering tooling (SwiftUI/Metal) instead of the flat-design HTML mockup constraints used for these early visuals.

---

## Implementation-path addendum (researched 2026-06-14)

The gap above is now closed at the API level — both pieces have concrete, current (iOS 26) building blocks. Still needs hands-on craft time, but this is no longer "figure it out later," it's "build it with `.glassEffect` + a `layerEffect` shader."

### Liquid glass material

SwiftUI ships a native API for this in iOS 26:

```swift
func glassEffect<S: Shape>(_ glass: Glass = .regular, in shape: S = DefaultGlassEffectShape, isEnabled: Bool = true) -> some View
```

- `Glass` variants: `.regular`, `.clear`, `.identity`, `.tint(_ color:)`, `.interactive()`. `.clear` gets closest to "see-through liquid" but should be paired with a dimming layer underneath for legibility.
- `GlassEffectContainer` + `.glassEffectID(_:in:)` coordinate multiple glass shapes that morph/merge together — relevant if the splash blob is ever decomposed into multiple glass elements rather than one shape. Glass can't sample other glass, so nearby glass elements need to be grouped in a container.
- Apply `.glassEffect()` last in the modifier chain.
- Our existing `Canvas`/`TimelineView` morphing-blob path generator (the SVG blob math already prototyped) can still drive the *shape* — `.glassEffect(.regular, in: thatShape)` gives it the material (translucency, refraction, specular) the flat mockup couldn't show.

Sources: [LiquidGlassReference (GitHub)](https://github.com/conorluddy/LiquidGlassReference), [LiquidGlassSwiftUI (GitHub)](https://github.com/mertozseven/LiquidGlassSwiftUI), [conor.fyi Liquid Glass reference](https://conor.fyi/writing/liquid-glass-reference), [TheSwiftKit](https://theswiftkit.com), [GetSkyscraper](https://getskyscraper.com), Apple Developer forums, [xcode-27-system-prompts (GitHub)](https://github.com/artemnovichkov/xcode-27-system-prompts).

### Touch ripple / "reacts like water"

Pattern confirmed across several recent (Feb–Mar 2026) writeups, all converging on the same approach:

- Use `.layerEffect`/`.colorEffect` with a stitchable Metal shader (Apple's SwiftUI shader API).
- Capture the touch point via `UIGestureRecognizerRepresentable` wrapping a spatial/long-press gesture (gives exact `CGPoint`).
- Shader computes distance from the tap origin, applies a sine-wave radial distortion, decays it exponentially over time, and samples the underlying layer at the displaced position — i.e. the literal "ripple expands and settles" effect.
- `keyframeAnimator` drives the decay-over-time animation feeding the shader.
- Multi-touch works the same way scaled to multiple origins (WWDC24 ShaderGraph/layerEffect).
- [twostraws/Inferno](https://github.com/twostraws/Inferno) is a ready-made library of Metal shaders for SwiftUI — good starting point rather than writing shaders from scratch.

Sources: [Ripple Effect with SwiftUI and Metal Shaders (Medium)](https://medium.com/@vickipetrova/ripple-effect-with-swiftui-and-metal-shaders-a-custom-water-scene-ba6ec524ca0d), [Liquid UI: Reactive Ripple Effect (Medium)](https://medium.com/@langellaluca00/liquid-ui-building-a-reactive-ripple-effect-in-swiftui-with-metal-97ecb29cb80a), [Building a Beautiful Ripple Effect (Medium)](https://medium.com/@pratap.shaoo123/building-a-beautiful-ripple-effect-in-swiftui-using-metal-shaders-50f7bde32878), [Multi-Touch Ripple Effects (SwiftUISnippets)](https://swiftuisnippets.wordpress.com/2026/03/24/multi-touch-ripple-effects-in-swiftui-with-metal-shaders/), [Hacking with Swift — Metal layer effects](https://www.hackingwithswift.com/quick-start/swiftui/how-to-add-metal-shaders-to-swiftui-views-using-layer-effects).

### Putting it together

The two effects are composable, not either/or: the morphing blob shape (already prototyped) → `.glassEffect()` for material → `layerEffect` ripple shader layered on top, keyed to touch position. Three independent layers that can be built and tuned separately.

### Net effect on "Status" above

Both open items now have a named, current API path. What remains is craft (timing, decay curves, glass tint/opacity tuning) — not technology selection.
