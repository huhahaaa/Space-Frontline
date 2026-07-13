# Task 2 Report: Arc Dash Path + easeOut + Threat Detection

## Status: COMPLETED

## What Was Changed

### 1. Replaced `_dodgeBullets` method (line 123)
The old method was a simple frame-by-frame positional displacement (`position += totalDodge * 90.0 * dt`). Replaced with a full state-machine driven dodge system:

- **Cooldown state**: ticks the cooldown timer, transitions back to idle after `_cooldownDuration` (1.5s)
- **Dodging state**: delegates to `_updateDodging(dt)` for arc path movement
- **Idle state**: scans for bullet threats using the same detection logic (perpendicular vectors, miss distance), but now picks the single closest threat and calls `_startDodge` to initiate an arc dash
- Also manages afterimage aging/removal and particle position/lifetime updates

### 2. Added 4 new methods (after `_dodgeBullets`)

- **`_easeOut(double t)`**: Quadratic ease-out function (1 - (1-t)²) for fast-in/slow-out motion
- **`_startDodge(Vector2 evadeDir)`**: Initializes dodge state machine — sets `_dodgeState = dodging`, stores start/control/end positions for a quadratic Bezier arc (control point 60px away, endpoint 80px away), clears afterimages and particles
- **`_updateDodging(double dt)`**: Per-frame arc dash update using quadratic Bezier interpolation with the easeOut curve, scale bounce (expand to 1.15x by 55% progress, shrink back to 1.0x), afterimage sampling, and particle emission. Transitions to cooldown on completion
- **`_emitDodgeParticle()`**: Spawns a particle in a backward-facing fan (-60 to +60 degrees from reverse dodge direction) with random speed (40-120 px/s), life (0.2-0.3s), and size (2-4px)

### 3. Modified `update` method (line 118)
Changed from a simple frozen/feared guard that skips all dodge logic:

```dart
// Before:
if (!isFrozen && !isFeared) {
  _dodgeBullets(dt);
}

// After:
if (!isFrozen && !isFeared) {
  _dodgeBullets(dt);
} else if (_dodgeState == _DodgeState.dodging) {
  _updateDodging(dt);
}
```

This ensures a currently-dodging JingLei finishes its arc dash even when frozen/feared, but cannot initiate a new dodge while under crowd control.

## Dart Analyze Output

```
Analyzing jing_lei_enemy.dart...

warning - jing_lei_enemy.dart:17:45 - A value for optional parameter 'age' isn't ever given.
warning - jing_lei_enemy.dart:107:10 - The value of the field '_scaleBounce' isn't used.

2 issues found.
```

- **0 errors** (as required)
- 2 warnings: both are unused fields from Task 1 (`_Afterimage.age` and `_scaleBounce`) that will be consumed in Tasks 3-4 (rendering afterimages and scale bounce visual effects)
