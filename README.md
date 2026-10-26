# Dragon Army iOS MVP

Dragon Army is a SwiftUI + SwiftData focus app with a calm game loop: complete focused work, grow your dragon, expand Azuremere Lake, unlock new dragon species, and track your consistency.

The dragon visual is a procedural RealityKit placeholder built from primitive meshes. It is intentionally not a reused image asset.

## Current features

- Three simple focus presets (15, 25, and 50 minutes) plus a custom duration from 1 to 180 minutes.
- Pause, resume, early completion, and persisted session history.
- Timestamp-based timer recovery when the app is backgrounded or reopened.
- Local notification when a running focus session finishes.
- Daily focus goal with progress tracking.
- Professional dashboard with today’s focus, all-time minutes, session count, seven-day consistency bars, current streak, average session length, weekly minutes, and goal-day count.
- Six dragon species with total collection progress and unlock milestones.
- Dragon evolution from hatchling to fledgling to guardian through earned XP.
- Azuremere Lake that expands after completed sessions, displays resident dragons, and unlocks lake projects such as the reed garden, moon bridge, and crystal isle.
- Dragon naming and color customization with matching 3D model colors.
- Six focus medals for milestones such as the first session, one focused hour, a three-day streak, deep work, and a weekly rhythm.
- SwiftData persistence for dragons, sessions, and lake discoveries.
- First-run Dragon Keeper onboarding with a local profile name, focus/lake/collection introduction, and saved welcome state.

## Open and run

1. Open `DragonArmy.xcodeproj` in Xcode.
2. Choose an iPhone Simulator or a connected iPhone.
3. Select the `DragonArmy` scheme and press the Run ▶ button.
4. In the app, open **Focus** to choose a duration and start a session. Open **Dashboard**, **Dragons**, and **Lake** to see the rewards.

The app seeds the Ruby starter dragon on first launch. If an old simulator data store causes a migration warning after model changes, erase that simulator’s app data and run again; this only resets test data.

The timer’s notification permission is requested the first time a focus session starts. If permission is declined, the in-app timer still works normally.

## Project structure

- `DragonArmy/DragonArmyApp.swift` — app entry point and SwiftData container.
- `DragonArmy/Models.swift` — persisted dragons, focus sessions, and lake discoveries.
- `DragonArmy/ContentView.swift` — dashboard, timer, collection, lake, rewards, and settings.
- `DragonArmy/OnboardingView.swift` — first-run Dragon Keeper profile and intro flow.
- `DragonArmy/DragonSceneView.swift` — procedural RealityKit dragon placeholder.
- `DragonArmy/Theme.swift` — shared visual language inspired by warm cartoon reds, cream, mint, and gold.

## Local folder or GitHub?

Keep it locally while prototyping; that is enough to open and run it in Xcode. A private GitHub repository is recommended once you want backup, version history, collaboration, or access from another Mac. GitHub is not required for the app to run, and this project currently contains no passwords or API keys.
