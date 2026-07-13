---
schema: "1.0"
name: space-frontline
version: "1.0.0"
description: >
  Load when working on "Space Frontline" — a tower defense roguelike game built with Flutter + Flame.
  Triggers when user references this project, its components, or any tower defense / roguelike mechanics.
  Covers: enemy types, buff system, wave system, status effects, damage system, coordinate conventions,
  asset loading patterns, and architectural decisions specific to this codebase.
triggers:
  keywords:
    primary:
      - space frontline
      - defend the tower
      - tower defense
      - 塔防
      - 防御塔
      - flame
      - FlameGame
      - PositionComponent
    secondary:
      - enemy
      - buff
      - wave
      - projectile
      - damage
      - roguelike
  context_boost:
    - flutter
    - dart
    - game
    - sprite
    - animation
  priority: high
dependencies:
  prerequisites:
    - flutter
    - dart
    - flame
  related:
    - flame-game-dev
    - flame-core
    - flame-templates
author: project
---

# Space Frontline — Tower Defense Roguelike

Space Frontline (星际前线) is a tower defense roguelike game built with Flutter + Flame.
The player defends a tower at the bottom of the screen from waves of descending enemies,
choosing buffs between waves to strengthen their defenses.

---

## Quick Reference

| Concept | File | Key Info |
|---------|------|----------|
| Main game | `lib/game/defend_the_tower_game.dart` | Game loop, wave spawning, collision, buff selection |
| Base enemy | `lib/game/components/enemy.dart` | `Enemy` class, only variant type1, `homingResistant`, `speedFactor` |
| Elite enemy | `lib/game/components/elite_enemy.dart` | `EliteEnemy` — uses enemy-2.png (16-frame spritesheet), shockwave at 2.5s |
| Nurse enemy | `lib/game/components/nurse_enemy.dart` | `NurseEnemy` — enemy-4 sprites, purge+heal every 2.5s, 100px radius |
| JingLei enemy | `lib/game/components/jing_lei_enemy.dart` | `JingLeiEnemy` — enemy-3 sprites, physics dodge, chain lightning, kill escalation |
| Projectile | `lib/game/components/projectile.dart` | Homing bullet, `velocity` getter for dodge prediction |
| Drone bullet | `lib/game/components/drone_bullet.dart` | `DroneBullet` — penetrating, no tracking |
| EMP wave | `lib/game/components/emp_wave.dart` | 16-frame spritesheet animation, golden tint via saveLayer |
| Damage number | `lib/game/components/damage_number.dart` | 0.85s duration, `.heal()` pink constructor, pure icon support |
| Buff manager | `lib/game/buffs/buff_manager.dart` | All buff values, multipliers, chain damage |
| Buff registry | `lib/game/buffs/buff_registry.dart` | Buff descriptions and level data |
| Status effects | `lib/game/buffs/status_effects/` | Burning, Slowed, Frozen, Marked, Feared, PurgeProtected |
| Purge protected | `lib/game/buffs/status_effects/purge_protected.dart` | 1s fire storm immunity component |

---

## Architecture

### Game Structure

```
lib/
├── main.dart                              → Entry point, GameWidget
├── game/
│   ├── defend_the_tower_game.dart         → Main FlameGame class (~2000+ lines)
│   ├── components/                        → All game entities
│   │   ├── enemy.dart                     → Base Enemy (type1 only)
│   │   ├── elite_enemy.dart               → Elite (enemy-2, shockwave)
│   │   ├── nurse_enemy.dart               → Nurse (enemy-4, purge+heal)
│   │   ├── jing_lei_enemy.dart            → JingLei (enemy-3, dodge+chain lightning)
│   │   ├── projectile.dart                → Homing bullet
│   │   ├── drone_bullet.dart              → Penetrating drone bullet
│   │   ├── emp_wave.dart                  → EMP spritesheet effect
│   │   ├── damage_number.dart             → Floating damage/heal numbers
│   │   ├── lightning_chain.dart           → Visual chain lightning effect
│   │   └── tower.dart                     → Tower (player base, not interactive)
│   └── buffs/
│       ├── buff_manager.dart              → All active buff values
│       ├── buff_registry.dart             → Buff definitions & descriptions
│       └── status_effects/                → Status effect components
│           ├── burning.dart
│           ├── slowed.dart
│           ├── frozen.dart
│           ├── marked.dart
│           ├── feared.dart
│           └── purge_protected.dart
```

### Key Pattern: Single-File Game Loop

The game logic is centralized in `DefendTheTowerGame` — a `FlameGame` with multiple mixins.
This is NOT ECS; it's a monolithic game object pattern. Components extend `PositionComponent`.

```dart
class DefendTheTowerGame extends FlameGame
    with HasCollisionDetection {
  // Game state, timers, spawn logic, collision detection, buff application
  // Enemy spawning, projectile launching, damage dealing — ALL in this file
}
```

### Component Lifecycle (Flame 1.26.1)

```dart
class MyComponent extends PositionComponent {
  // 1. Constructor — minimal setup only
  MyComponent() : super(size: Vector2(32, 32), anchor: Anchor.center);

  // 2. onLoad — async asset loading (called once)
  @override
  Future<void> onLoad() async {
    sprite = await Sprite.load('image.png');
    // Set size based on sprite dimensions
  }

  // 3. onMount — component added to tree, game ref available
  @override
  void onMount() {
    super.onMount();
    // Start timers, subscribe to events
  }

  // 4. update — every frame (ALWAYS call super.update(dt))
  @override
  void update(double dt) {
    super.update(dt);
    // Game logic
  }

  // 5. render — draw to canvas (optional canvas.save/restore)
  @override
  void render(Canvas canvas) {
    super.render(canvas);
    // Custom drawing
  }

  // 6. onRemove — cleanup
  @override
  void onRemove() {
    // Cancel timers, unsubscribe
    super.onRemove();
  }
}
```

---

## Coordinate Convention (CRITICAL)

**"Height" is ALWAYS measured from bottom up.**

```
y = 0        → Top of screen (enemy spawn point)
y = size.y   → Bottom of screen (tower position)
```

| Phrase | Meaning | Code |
|--------|---------|------|
| "Below X% height" | Position is closer to tower | `y > size.y * (1.0 - X/100)` |
| "Above X% height" | Position is closer to top | `y < size.y * (1.0 - X/100)` |
| Tower position | `y = size.y * 0.92` | Bottom 8% of screen |
| "低于地图高度92%" | `y > size.y * 0.08` | Enemies below 92% from top |

**Memory**: [[coordinate-convention]]

---

## Enemy System

### Enemy Hierarchy

```
PositionComponent
  └── Enemy (base, enemy-1.png, static sprite)
        ├── EliteEnemy (enemy-2.png, 16-frame spritesheet, shockwave)
        ├── NurseEnemy (enemy-4/, 3-frame spritesheet, purge+heal)
        └── JingLeiEnemy (enemy-3.png, 4-frame spritesheet, dodge+chain lightning)
```

### Base Enemy Properties

```dart
class Enemy extends PositionComponent {
  static const double baseSpeed = 50.0;    // Pixels per second base
  static const double baseHp = 3.0;        // Base HP
  double get speedFactor => 1.0;           // Override for speed modifiers
  bool get homingResistant => false;       // Override for anti-homing
  int expValue = 10;

  // States
  bool isBurning, isSlowed, isFrozen, isFeared, isMarked;
  bool isFlammable;  // Fire Storm applied

  // Movement (handled in update):
  // position.y += effectiveSpeed * speedMultiplier * speedFactor * dt
  // Frozen: no movement
  // Feared: moves UP (away from tower)
}
```

### Enemy Spawning Pattern

All spawning is handled in `DefendTheTowerGame._spawnWave(dt)`:
- Regular enemies: type1, spawned on interval
- Elite enemies: `_spawnElite()`, specific wave intervals
- Nurse enemies: `_spawnNurse()`, wave 5+
- JingLei enemies: `_spawnJingLei()`, wave 1+, every `currentSpawnInterval * 5`

```dart
// Spawn position: top of screen (y close to 0), random x
// Enemies move downward: position.y += speed * dt
```

### Enemy Type Spawning Logic

```dart
// Regular enemy spawn is wave-based
// Each wave has: enemyCount, spawnInterval, hpMultiplier, speedMultiplier, expValue

// Wave 15 (final wave):
// - double duration (30s)
// - double spawn rate (half interval)
// - must clear all enemies to win (no early stop)

// stopSpawning check:
// final stopSpawning = _waveClearing;  // Only stops when clearing mode
```

---

## Buff System

### Buff Selection Flow
1. After each wave completes, show buff selection overlay
2. Player picks 1 of 3 random buffs
3. Buffs have 3 levels (Lv.1 → Lv.2 → Lv.3)
4. If already at Lv.3, buff won't appear in selection

### Active Buffs (BuffManager)

| Buff | Lv.1 | Lv.2 | Lv.3 | Type |
|------|------|------|------|------|
| **Rapid Fire** (急速射击) | 0.78× fire rate | 0.62× | 0.48× + 15% double | Fire rate |
| **Power Shot** (强化弹头) | 1.30× damage | 1.30×1.50=1.95× | 1.95×1.70=3.315× | Cumulative mult |
| **Chain Lightning** (闪电链) | 0.6 dmg, 1 bounce | 0.6 dmg, 2 bounces | 1.0 dmg, 2 bounces, 30% slow | On-hit chain |
| **Fire Storm** (火焰风暴) | Pull + 1.0 fireball/s, flammable | Same + 10% dmg vs flammable | Same + 20% dmg vs flammable | AOE |
| **Static Field** (静电场) | 20 dmg, below 92% height, every 3s | Same | Same | Timed AOE |
| **EMP Wave** (电磁脉冲) | Stun all 1.5s, every 15s | Same | Same | Timed CC |
| **Frost Aura** (冰霜光环) | 20% slow, 80px | 35% slow, 100px | 50% slow, 120px | Aura |
| **Marking** (弱点标记) | +50% dmg taken, 2s | +70%, 2.5s | +100%, 3s | Debuff |

### Buff Implementation Pattern

```dart
// Buff values stored in BuffManager fields
// Applied in game loop during collision/damage calculations

// Example: Chain lightning
final chainDmg = bm.chainDamage;  // Flat damage, NOT multiplied by bullet damage
// Lv.3 slow: added Slowed(factor: 0.30, duration: 2.0) to chained target

// Example: Power Shot (cumulative multiplicative)
// Lv.1: 1.30
// Lv.2: 1.30 * 1.50 = 1.95
// Lv.3: 1.95 * 1.70 = 3.315
// Each level pick multiplies the CURRENT multiplier by the new factor
```

---

## Status Effects

### Standard Effects (as Components)

```dart
// All status effects are added as child components:
enemy.add(Slowed(factor: 0.30, duration: 2.0));
enemy.add(Burning(damage: 0.5, duration: 3.0));
enemy.add(Frozen(duration: 1.5));
enemy.add(Marked(multiplier: 1.5, duration: 2.0));
enemy.add(Feared(duration: 1.0));
enemy.add(PurgeProtected(duration: 1.0));

// Checking status:
enemy.isBurning    // → firstChild<Burning>() != null
enemy.isSlowed     // → firstChild<Slowed>() != null
enemy.isFrozen     // → firstChild<Frozen>() != null
```

### PurgeProtected (Nurse Special)
- 1 second timer component
- Prevents fire storm pull (attraction)
- Prevents flammable debuff application
- Auto-removes when timer expires
- Game checks: `final ccImmune = (purged != null && purged.isActive) || jlImmune;`

### Status Interactions
- **Frozen** → enemy stops moving entirely
- **Feared** → enemy moves UP (away from tower, reversed direction)
- **Frozen/Feared** → JingLei cannot dodge
- **Nurse Purge** → clears Burning, Shocked, Slowed; adds PurgeProtected
- **JingLei Final Form** → immune to slow, immune to fire storm pull (`immuneToCrowdControl`)

---

## Damage System

### Damage Number Display

```dart
// Regular damage (white/red)
DamageNumber(value: damage, position: enemy.position);

// Critical hit (larger, orange)
DamageNumber(value: damage, position: enemy.position, isCrit: true);

// Healing (pink, +x ❤️)
DamageNumber.heal(amount: healAmount, position: target.position);

// Pure icon (no number) — e.g., dodge indicator
DamageNumber(icon: '💨', amount: 0, position: enemy.position);

// Duration: 0.85s
// Velocity: original × 0.85
// Gravity: 141 (was 120, scaled proportionally)
```

### Damage Flow
1. Projectile hits enemy → `enemy.takeDamage(damage)`
2. If enemy has `isMarked` → damage * multiplier
3. If enemy is `isFinalForm` (JingLei) → damage * 0.5 (50% DR)
4. Damage number created and added to game
5. On death → exp added, kill counted, buff effects triggered

### Chain Lightning Damage
```dart
// Chain damage is FLAT, not multiplied by source bullet damage
final chainDmg = bm.chainDamage;  // 0.6 (Lv.1-2) or 1.0 (Lv.3)
// vs old incorrect: bullet.damage * bm.chainDamageRatio
```

### Bottom Damage (enemies reaching tower)
```dart
final dmg = (enemy is JingLeiEnemy && enemy.isFinalForm) ? 10 : 5;
```

---

## Bullet / Projectile System

### Projectile
- Homing enabled by default (`homingStrength = 0.15`)
- Skips homing for `homingResistant` enemies (JingLeiEnemy)
- Exposes `velocity` getter for physics dodge prediction
- `applyBuffs` flag: false for split bullets before Lv.3 chain lightning
- `visualScale`: 0.5 for split bullets
- `isSplit`: true for split bullets (prevents recursive splitting)
- Max lifetime: 3.0s

### DroneBullet
- Penetrating: hits multiple enemies (tracks via `_hitEnemies` Set)
- No tracking (straight line only)
- Speed: 560, Damage: 2.0
- Size: 69×30 (from 212×92 sprite)

### Double Shot (Rapid Fire Lv.2+)
```dart
// 15% chance (Lv.3), angled for visibility:
_launchBullet(finalDamage, target, angleOffset: 0.13);
// angleOffset rotates the launch direction slightly for visual separation
```

---

## Special Enemy Mechanics

### EliteEnemy
- 16-frame spritesheet (enemy-2.png)
- Shockwave every 2.5s (was 5.0s)
- Shockwave: 3.0 damage, 250px radius

### NurseEnemy (护士)
- Wave 5+ only
- enemy-4/ 3-frame sprites (52px height — 35% larger than regular)
- HP: baseHp * hpMultiplier * 1.5
- Speed: 0.5× base (slow support unit)
- **Purge+Heal**: Every 2.5s, radius 100px
  - Clears Burning, Shocked, Slowed from all friendlies in range
  - Heals 80% of missing HP
  - Adds PurgeProtected (1s fire storm immunity)
  - Pink radial gradient glow visual
  - Highlight: alpha 0.15→0.90 peak on trigger, 0.5s decay

### JingLeiEnemy (惊雷)
- Wave 1+, every `currentSpawnInterval * 5`
- enemy-3.png 4-frame spritesheet (128×32, each 32×32)
- HP: baseHp * hpMultiplier * 1.5
- Initial speed: 0.5× (slow start)
- **Homing resistant**: Bullets don't track this enemy
- **Physics dodge** (when not frozen/feared):
  - Detect: 120px radius
  - Threshold: 38px miss distance (dodge if closer)
  - Speed: 90px/s perpendicular evasion
  - Uses bullet trajectory prediction: `t = dot(toSelf, bulletVel) / dot(bulletVel, bulletVel)`
- **Chain lightning attack** every 1.0s:
  - Range: 200px
  - Damage: 5.0 per hit
  - Targets nearest non-JingLei/non-Nurse enemy
  - LightningChain visual + DamageNumber per hit
- **Kill escalation**:
  - Each friendly kill: +0.5× speed multiplier
  - After 3 kills → Final Form:
    - 50% damage reduction (`takeDamage` override)
    - Slow/pull immune (`immuneToCrowdControl`)
    - 10 HP bottom damage (vs normal 5)
    - No more chain lightning attacks
    - Auto-clears Slowed status

---

## Visual Effects

### EMP Wave
- 16-frame spritesheet (2048×128, each 128×128)
- Tinted golden: `Color.fromRGBO(255, 200, 0, 0.45)` with `BlendMode.srcATop`
- Preload system with `_loading` mutex guard

### Radial Gradient Glow (Nurse)
```dart
final glowPaint = Paint()
  ..shader = Gradient.radial(
    Offset(cx, cy),  // Center of component
    r,               // Radius
    [centerColor, edgeColor, Colors.transparent],
    [0.0, 0.3, 1.0],
  );
// Key: Gradient.radial is from dart:ui, not Flutter's RadialGradient
```

### Lightning Chain Visual
```dart
// Game-side creation: this.add(LightningChain(from: jingLei.position, to: target.position))
// NOT created inside enemy.tryChainAttack() — findGame() may return null there
```

---

## Wave System

### Wave Configuration
```dart
// 15 waves total
// Wave properties: enemyCount, spawnInterval, hpMultiplier, speedMultiplier, expValue
// Wave 15:
//   - duration: waveDuration * 2 (30s)
//   - spawn rate: interval * 0.5 (double enemies)
//   - clear-to-win: no early stop on timer
```

### Wave Clearing
```dart
// _waveClearing flag set when:
// - All enemies spawned AND all dead
// - Or timer expired (except wave 15)

// stopSpawning:
// final stopSpawning = _waveClearing;  // true when clearing, stops new spawns
```

---

## Preloading Pattern

```dart
// Static preload with mutex guard (prevents double-load)
static List<Sprite>? _frames;
static bool _loading = false;

static Future<void> preload() async {
  if (_frames != null || _loading) return;
  _loading = true;
  final image = await Flame.images.load('asset.png');
  _frames = List.generate(count, (i) {
    return Sprite(image,
      srcPosition: Vector2(i * frameW, 0),
      srcSize: Vector2(frameW, frameH),
    );
  });
  _loading = false;
}

// Called in game.onLoad: await EmpWave.preload();
```

---

## Key Rules for This Project

### DO:
- Use `super.update(dt)` in every `update()` override
- Use `Anchor.center` for all game entities
- Load assets in `onLoad()`, not constructors
- Use `firstChild<T>()` to check for status effects
- Handle game-side rendering in `DefendTheTowerGame` (not inside component `findGame()` calls)
- Preload spritesheet-based animations with mutex guard pattern
- Use flat damage values for chain lightning (not multiplied)
- Remember: "height" = bottom-up (y increases downward)
- Spawn JingLei at `startY = 0` (top of screen)
- Use `enemy.add(StatusEffect(...))` for applying status effects

### DON'T:
- Don't call `findGame()` in component `try*()` methods — return data, let game handle rendering
- Don't multiply chain damage by bullet damage (it's flat)
- Don't create new objects in `update()` or `render()` — reuse fields
- Don't use `EnemyVariant.type2/type3/type4` — those are separate classes now
- Don't track bullets toward `homingResistant` enemies
- Don't apply dodge when frozen/feared
- Don't reverse the height convention (0=top, max=bottom)
- Don't forget `visualScale` for split bullets
- Don't skip `super.render(canvas)` in render overrides

---

## Common Patterns

### Adding a New Enemy Type
1. Create class extending `Enemy` with `super(variant: null)`
2. Override `onLoad()` for sprite loading
3. Override getters: `speedFactor`, `homingResistant`, `maxHp`
4. Override `takeDamage()` if special handling needed
5. Add spawn method in `DefendTheTowerGame`
6. Add spawn timer field
7. Register in collision checks (bottom damage, fire storm pull, etc.)
8. Add to `_spawnWave` or separate spawn timer

### Adding a New Buff
1. Add fields in `BuffManager`
2. Add level data in `BuffRegistry`
3. Implement effect in game loop
4. Add description in `BuffRegistry`
5. Handle Lv.3 special effects

### Adding a New Status Effect
1. Create component class in `status_effects/`
2. Add auto-remove timer
3. Add check getter in `Enemy` base class
4. Handle in relevant game systems

---

## Version History
- v1.0.0 — Initial project skill: architecture, enemies, buffs, conventions, patterns
