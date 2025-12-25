# Kraftli Timers – Claude Instructions

Kraftli Timers is a native iOS fitness app built with SwiftUI for high-intensity, minimalistic workouts.

## Goals
- Learn iOS development and SwiftUI best practices through a real-world project.  
- Provide a lightweight workout timer app tailored to short, focused sessions (20 min, up to 4× per week) without bloated features.

## Tech Stack
- **Platform:** iOS 26+  
- **UI:** SwiftUI  
- **Persistence:** TBD; SwiftData likely  

## Features v1
- **EMOM Timer:** Interval-based workouts; complete exercises each interval. The interval duration can be customized (e.g., total duration divided by number of reps).  
- **AMRAP Timer:** Time-based rounds; track as many rounds as possible.  
- **Preset Management:** Save and reuse favorite timer configurations.  
- **UI:** Minimalistic and visually clean.  

## Domain Model v1
- **TimerPreset:** `id`, `kind`, `duration`, `exercise`, `reps` (optional, for EMOM; interval can be customized)  
- **TimerKind:** Enum: `EMOM` or `AMRAP`  
- **Exercise:** Name (e.g., 6 Count Burpees, Navy Seals, High Jumps, Push-ups, Pull-ups)  

## Claude Workflow Guidelines
1. **Planning First:** Before writing any code, summarize the intended approach. Include assumptions and options.  
2. **Ask Questions:** If any requirement, behavior, or design decision is unclear, list them explicitly and wait for confirmation.  
3. **Stepwise Implementation:** Break features into small, testable steps. Implement only after plan approval.  
4. **Branching & Versioning:** For every new feature or bug fix, create a separate Git branch and prepare a pull request for review.  
5. **Simplicity:** Prefer minimal, composable solutions over complex abstractions. Avoid unnecessary features.  
6. **Feedback Loop:** After each implementation step, summarize results and ask if adjustments are needed before proceeding.
