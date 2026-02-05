# Scrolling Overview

## Goals
- Provide a niri-style horizontal overview for scrolling mode.
- Use live thumbnails when available; fallback to icon + title.
- Keyboard navigation (left/right), Enter to activate, Esc to close.
- Pause focus border updates while overview is open.

## Phase 1 Tasks (MVP)
- Add `src/lib/scrolling_overview.ahk` with DWM thumbnail plumbing.
- Implement overlay GUI layout (center + sides) with scaling/spacing.
- Add window data adapter from scrolling mode (ordered list + center index).
- Implement input handling (Left/Right/Enter/Esc) without wrapping.
- Pause focus border updates while overview is open; resume on close.
- Add config schema + defaults for `modes.scrolling.overview`.
- Hook `super + o` when scrolling is active.
- Manual checks:
  - Open overview, navigate left/right, select, cancel.
  - Verify fallback icon + title when thumbnail fails.
  - Ensure focus border pauses/resumes correctly.

## Phase 2 Tasks (Polish)
- Add simple animations for selection shifts.
- Add mouse click selection.
- Make visible count and spacing fully configurable.

## Phase 3 Tasks (Enhanced Navigation)
- Add search/filter inside overview.
- Add a small index/position indicator.
