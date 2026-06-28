# Merge Royal — Android merge/2048 card game

Neon-themed card-merge game (Flutter + Flame). Drag the front card of a column
onto a matching card to merge (2+2→4 … →4096+), build staircases for combo
multipliers, manage mistakes, and use bomb/shuffle power-ups.

## Stack
- **Flutter 3.44 / Dart 3.12**, **Flame 1.37** (2D game engine).
- `flame_audio` — SFX + looping music bed (assets synthesized as WAV, see below).
- `in_app_update` — Google Play flexible/background updates.
- `google_fonts` (Silkscreen / Baloo2 — fetched at runtime; consider bundling for offline).
- `shared_preferences` for save/continue + best score + mute flag.
- Targets: **android** (primary), ios, windows, web (bonus, builds clean).

## Audio / effects / updates
- `lib/audio/audio_controller.dart` — singleton; preloads SFX, plays `music.wav`
  loop, persisted `muted` ValueNotifier shared by menu + pause. Hooked to game
  events (merge/combo/bomb/shuffle/mistake/levelup/gameover) + button taps.
- `assets/audio/*.wav` are **procedurally generated** (no licensed assets) by
  `tool/gen_audio.py` — re-run it to tweak the sounds.
- Effects in `merge_royal_game.dart`: particle bursts on merge/bomb
  (`ParticleSystemComponent`) + screen-shake (canvas translate in `render`).
  Level-up **confetti** is a `CustomPainter` in `overlays.dart`.
- `lib/services/update_service.dart` — checks Play for updates on launch and
  runs a flexible (background-download) update, then a "Restart" snackbar.
  Android-only; only fires for Play-installed builds (no-op on debug/sideload).

## Architecture
All rules live in a plain `ChangeNotifier`; Flame only renders + routes input.

```
lib/
  main.dart                       app entry, portrait + immersive
  theme/app_theme.dart            neon palette, fonts, per-value card gradients
  models/card_data.dart           CardData (value/suit/locked) + Suit enum
  game/
    game_controller.dart          THE source of truth: board, scoring, levels,
                                  spawns, mistakes, power-ups, persistence
    board_layout.dart             responsive geometry (recomputed on resize)
    merge_royal_game.dart         FlameGame: syncs components from controller,
                                  handles drag (DragCallbacks) + bomb (TapCallbacks)
  components/
    card_component.dart           canvas-drawn card (no image assets)
    background_component.dart     column progress bars, empty-slot glow, dashed line
  ui/
    neon_widgets.dart             NeonButton / NeonIconButton / NeonPanel / NeonText
    hud.dart                      TopHud (level+progress+score+combo), PowerBar
    overlays.dart                 Pause / LevelUp / GameOver / HowToPlay dialogs
    main_menu_screen.dart         CONTINUE / NEW GAME
    game_screen.dart              hosts GameWidget + Flutter HUD + overlays
test/widget_test.dart             merge / mistake / combo logic tests
```

### Data flow
`GameController` owns `columns: List<List<CardData>>` (4 cols, last element =
front/playable card). It `notifyListeners()` after every change; `MergeRoyalGame`
listens and `sync()`s card components to match (creating, animating, removing).
Flutter HUD/overlays rebuild via `AnimatedBuilder(animation: controller)`.

## Game rules (v1)
- Drag the **front** card (last in a column) onto another column.
  - Drop on **empty** column → free relocation.
  - Drop on a column whose front **equals** the dragged value → **merge**
    (greedy front cascade: keeps merging while the two front cards match →
    builds combos; `comboMultiplier` drives the "X2" flash).
  - Any other non-empty drop → **illegal** → costs one **mistake**.
- `draggableCount` (3–5, scales with level): max size of an equal-value run you
  can grab from the front at once.
- **Spawns**: after each move a new low card drops into the emptiest column.
  Hazard/special chances scale with level.
- **Suit cards** (♠♥♣♦♛): on merge → spade=+score, heart=+1 mistake, club=+1 bomb,
  diamond=+1 shuffle, crown=jackpot score.
- **Locked card (🚫)**: blocks a column, can't merge → destroy with a **bomb**
  (tap bomb to arm, then tap the column).
- **Shuffle**: redistributes all cards across columns.
- **Level**: `levelScore` fills the top bar toward `levelTarget = 1000 + level*900`;
  on fill → LEVEL UP, `levelScore` resets (the big number under the bar), rewards.
- **Game over**: mistakes hit 0, or board full with no legal move and no power-ups.

## Branding / store assets
- App display name: **Merge Royal** (AndroidManifest `android:label`, iOS
  `CFBundleDisplayName`). applicationId `vn.vodongha.merge_royal`.
- Launcher icons: `assets/icon/{icon,foreground,background}.png` →
  generated into Android/iOS/web/windows via `dart run flutter_launcher_icons`.
- `store/` holds Play Store upload art (not bundled): `play_icon_512.png`
  (512×512 listing icon), `feature_graphic_1024x500.png` (header), `logo.png`.
- All art (icons + store) is **procedurally drawn** by `tool/gen_icons.py`
  with Pillow (neon two-card motif). Re-run it, then `flutter_launcher_icons`,
  to change the look.

## Commands
```bash
flutter pub get
flutter test                       # logic tests
flutter run -d <android-device>    # play on device/emulator
flutter build apk --release        # build APK
flutter build appbundle --release  # build AAB for Play Store
```

## Conventions (personal repos)
- Branches: `feature/*`/`bug/*`→`develop`, `hotfix/*`→`master`, release = PR develop→master.
  Never commit directly to `master`.
- Git identity: vodongha@hotmail.com (local). applicationId: `vn.vodongha.merge_royal`.

## TODO / next
- Bundle the Google Fonts as assets (offline) instead of runtime fetch.
- Android release signing (keystore) before Play upload.
- Optional: bump bgm/sfx quality (current WAVs are simple synth tones).
- Done: ✅ audio (SFX+music+mute) ✅ merge/bomb particles + shake ✅ level-up
  confetti ✅ Play in-app (flexible) updates.
