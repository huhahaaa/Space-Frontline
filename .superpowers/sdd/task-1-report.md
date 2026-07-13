# Task 1 Report: Add Dodge State Machine and Data Structures

## Status: DONE_WITH_CONCERNS

## What Was Changed

**File modified:** `D:/新建文件夹/defend_the_tower/lib/game/components/jing_lei_enemy.dart`

### 1. Added enum and data classes (before `class JingLeiEnemy`)

- `enum _DodgeState { idle, dodging, cooldown }` -- state machine states
- `class _Afterimage` -- afterimage sample data (position, age)
- `class _DodgeParticle` -- dash particle data (pos, vel, life, size)

### 2. Replaced old dodge constants with new fields

**Removed:**
- `static const double _dodgeSpeed = 90.0;` (replaced by arc dash in Task 2)

**Kept (still used by IDLE threat detection):**
- `static const double _dodgeDetectRadius = 120.0;`
- `static const double _dodgeThreshold = 38.0;`

**Added state machine fields:**
- `_DodgeState _dodgeState = _DodgeState.idle;`
- `double _dodgeTimer = 0;`
- `static const double _dodgeDuration = 0.18;`
- `static const double _cooldownDuration = 1.5;`

**Added arc dash parameters:**
- `Vector2 _dodgeStartPos = Vector2.zero();`
- `Vector2 _dodgeControlPoint = Vector2.zero();`
- `Vector2 _dodgeEndPos = Vector2.zero();`
- `Vector2 _dodgeDirection = Vector2.zero();`

**Added afterimage fields:**
- `final List<_Afterimage> _afterimages = [];`
- `static const double _afterimageSampleInterval = 0.04;`
- `static const int _maxAfterimages = 3;`
- `double _afterimageSampleAccum = 0;`

**Added particle fields:**
- `final List<_DodgeParticle> _particles = [];`
- `final Random _rng = Random();`
- `static const double _particleEmitRate = 30;`
- `double _particleEmitAccum = 0;`

**Added visual effect field:**
- `double _scaleBounce = 1.0;`

### 3. Fixed compilation error

Replaced `_dodgeSpeed` reference in `_dodgeBullets()` (line 172) with literal `90.0` since the constant was removed.

## Dart Analyze Output

```
warning - unused_field (x18): All new fields are unused -- expected, will be wired in Tasks 2-5
warning - unused_field: enum values 'dodging' and 'cooldown' -- expected, used in Task 2 state machine
warning - unused_element_parameter: _Afterimage.age default value -- expected, age will be set in Task 3
info - prefer_final_fields (x9): Fields will be mutated in subsequent tasks (e.g., _dodgeState, _dodgeTimer, _dodgeStartPos)
```

**Zero errors.** All warnings are `unused_field` / `unused_element_parameter` for fields intentionally added as stubs for Tasks 2-5. These will resolve as the fields are wired up in subsequent tasks.

## Concerns

1. **20 warnings remain** -- all are `unused_field` variants for the new fields added in this task. These fields are not yet referenced by any logic (that logic is added in Tasks 2-4). The warnings will self-resolve as tasks progress.

2. **No compile errors** -- the code compiles and the file is structurally correct.
