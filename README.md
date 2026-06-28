# 🃏 Merge Royal — *Merge to Win*

A neon-themed **merge / 2048 card game** for Android, built with **Flutter + Flame**.

Drag the front card of a column onto a matching card to **merge** (2 + 2 → 4 …
→ 4096+). Build staircases (2, 4, 8, 16…) to trigger **combo multipliers**,
spend your limited **mistakes** wisely, and use **bomb** 💣 and **shuffle** 🔀
power-ups to survive as the board fills up.

## Features
- 🎴 Drag-and-drop card merging with cascading **combos** (X2 / X3 …)
- 🏆 Level progression with a target score bar + **LEVEL UP!** celebration
- ❤️♠♣♦♛ **Suit cards** that grant bonus score, mistakes, bombs or shuffles
- 🚫 **Locked cards** you blow up with a bomb
- 💾 **Continue** your run (auto-save) + best-score tracking
- 🎨 Fully canvas-drawn cards & neon UI — **no image assets required**
- 📱 Portrait, immersive, responsive layout

## Run it
```bash
flutter pub get
flutter run            # on a connected Android device / emulator
```

## Build
```bash
flutter build apk --release          # APK
flutter build appbundle --release    # AAB for Google Play
```

## Tech
Flutter 3.44 · Dart 3.12 · Flame 1.37 · shared_preferences · google_fonts

See [CLAUDE.md](CLAUDE.md) for architecture and game-rule details.
