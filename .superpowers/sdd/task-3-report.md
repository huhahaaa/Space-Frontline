# Task 3 Report: Visual Rendering (Afterimages, Particles, Dodge Effects)

## Status: COMPLETE

## Changes Made

### File: `D:/新建文件夹/defend_the_tower/lib/game/components/jing_lei_enemy.dart`

### 1. Added `import 'dart:ui';`
Ensures all rendering types (`Canvas`, `Paint`, `Color`, `ColorFilter`, `BlendMode`, `Gradient`, `Offset`, `Rect`, `PaintingStyle`) are explicitly available.

### 2. Added `_particlePaint` field (line 109)
```dart
final Paint _particlePaint = Paint()..style = PaintingStyle.fill;
```
Reusable Paint object to avoid allocations per frame during particle rendering.

### 3. Added `render()` override (lines 127-153)
- **Particles beneath**: Calls `_renderParticles(canvas)` first
- **Afterimages beneath**: Calls `_renderAfterimages(canvas)` second
- **Scaled body**: Saves canvas, applies `_scaleBounce` scale transform centered on the component (translate to center, scale, translate back for Anchor.center), then calls `super.render(canvas)`
- **Purple overlay**: When dodging, draws a semi-transparent purple rectangle over the body at `Color.fromRGBO(160, 120, 255, 0.25)`

### 4. Added `_renderAfterimages()` method (lines 327-369)
- Iterates over `_afterimages` list
- Calculates alpha with a fade-in/fade-out curve: 0 to 0.05s ramps to 0.35 alpha, 0.05s to 0.2s fades to 0
- Converts world-space afterimage position to local offset relative to component
- Uses `canvas.saveLayer()` to apply a purple color filter (`Color.fromRGBO(180, 140, 255, alpha)` with `BlendMode.srcATop`)
- The saveLayer rect is centered at (0,0): `Rect.fromLTWH(-size.x/2, -size.y/2, size.x, size.y)` to account for Anchor.center

### 5. Added `_renderParticles()` method (lines 371-395)
- Iterates over `_particles` list
- Calculates `lifeRatio = p.life / 0.3` (clamped 0..1)
- Converts world-space particle position to local offset
- Uses a radial gradient shader with three color stops:
  - Center: purple-white at full lifeRatio
  - Mid: darker purple at lifeRatio * 0.3
  - Edge: fully transparent
- Draws a filled circle for each particle

## Verification

```
$ dart analyze lib/game/components/jing_lei_enemy.dart
warning - jing_lei_enemy.dart:18:45 - A value for optional parameter 'age' isn't ever given.
  Try removing the unused parameter. - unused_element_parameter

1 issue found.
```

- **0 errors** (target achieved)
- The single warning is pre-existing from Task 1/2 (`_Afterimage.age` parameter has a default value that is never explicitly overridden). This is a lint warning, not an error, and is unrelated to Task 3 changes.
- All previously unused field warnings resolved: `_afterimages`, `_particles`, `_scaleBounce`, `_particlePaint` are now consumed by `render()` and its helper methods.
