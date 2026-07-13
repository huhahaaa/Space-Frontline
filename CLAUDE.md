# Space Frontline — Tower Defense Roguelike

A tower defense roguelike built with **Flutter 3.x + Flame 1.26.1**.

## Skills

This project uses Claude Code skills. Key skills loaded automatically:

| Skill | Path | Triggers |
|-------|------|----------|
| **space-frontline** | `.claude/skills/space-frontline/SKILL.md` | Project-specific: enemies, buffs, waves, conventions |
| **flame-game-dev** | `.claude/skills/flame-game-dev/SKILL.md` | General Flame engine development |
| **flame-core** | `.claude/skills/flame-game-dev/flame-core/SKILL.md` | Core Flame concepts (components, collision, etc.) |
| **flame-systems** | `.claude/skills/flame-game-dev/flame-systems/SKILL.md` | Game systems (combat, saves, procedural, etc.) |
| **flame-templates** | `.claude/skills/flame-game-dev/flame-templates/SKILL.md` | Game templates (roguelike, RPG, platformer) |

## Project Conventions

### Dart / Flutter
- Use `camelCase` for variables, `PascalCase` for classes
- No `print()` — use `debugPrint()` or `package:logging`
- Always type-annotate public APIs
- Use `const` constructors where possible

### Flame
- Extend `PositionComponent` with `Anchor.center` for all game entities
- Always call `super.update(dt)` first in `update()` overrides
- Load assets in `onLoad()`, not constructors
- Prefer `firstChild<T>()` over manual component traversal
- Avoid `findGame()` inside component methods — return data to the game loop

### Architecture
- Game logic centralized in `DefendTheTowerGame`
- Enemy behavior in dedicated component classes (not the base Enemy class)
- Status effects as child `Component` instances
- Buff values in `BuffManager`, definitions in `BuffRegistry`
- Pure data return from component methods; rendering done game-side

### Coordinate System
- **Height is measured from bottom up** (y=0 is top, y=size.y is bottom)
- Tower is at `y = size.y * 0.92`
- "Below X% height" = `y > size.y * (1.0 - X/100)`

### Resources
- [Flame Docs](https://docs.flame-engine.org/)
- [Flutter AI Rules](https://docs.flutter.dev/ai/ai-rules)
- [Flame Engine Benchmarks](https://filiph.net/text/benchmarking-flutter-flame-unity-godot.html)
