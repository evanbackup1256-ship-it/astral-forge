# Original User Request

## 2026-10-12T00:07:05Z

Execute a comprehensive feature expansion, cinematic motion overhaul, and platform polish across Astral Forge v2 on Roblox, operating under strict declarative React architecture and robust multi-device support.

Working directory: c:\Users\evanm\OneDrive\Desktop\Astral Forge v2
Integrity mode: development

## Requirements

### R1. Core Progression & Gameplay Expansion
- Expand forge milestone depth, interactive encounter mini-events, and reward synthesis loops.
- Guarantee strict economy projection stability and lossless save/load data serialization between v4.12 and v5.0+.
- Preserve all existing UI functionality, tools, and data readouts through spatial optimization rather than feature deletion.

### R2. Cinematic UI Motion & VFX Physics Revamp
- Elevate crate opening sequences and prize wheel mechanics with multi-phase suspense, rumble keyframes, and spring-damped oscillation.
- Ensure all spatial transitions (panel slides, drawer expansion, modal popups) execute concurrently without state-locking or stuttering.
- Provide fluid, tactile feedback with velocity-sensitive scrolling and glowing hover accents.

### R3. Flawless Omni-Platform UX (Mobile, Tablet, Console, Ultrawide PC)
- Maintain absolute hardware safe-zone conformity (dynamic islands, notches, punch-holes) and aspect ratio agnosticism (foldables, 4:3, 16:9, 19.5:9, 21:9 ultrawide).
- Provide touch hitboxes with fat-finger forgiveness and zero hitbox-to-screen coordinate offsets.
- Support full Xbox console certification standards with D-pad / thumbstick focus-navigation and zero virtual cursor dependencies.

### R4. Architectural Guardrails & Audio Fidelity
- Interface elements must remain 100% declarative React components with zero imperative `Instance.new` for UI.
- All module imports must use Luau `require` with zero legacy `TS.import` dependencies.
- Maintain a multi-bus audio hierarchy (Master, Music, SFX, UI, Ambient) with bespoke UI auditory feedback.
- All telemetry and system logs must remain concise and severity-tagged (`[INFO]`, `[WARN]`, `[ERROR]`, `[FATAL]`, `[NETWORK]`), completely avoiding AI-generated narrative copy.

## Acceptance Criteria

### Test Verification Suite
- [ ] Programmatic test suite exits 0 (`npm test`) with zero regressions across all 50+ test suites.
- [ ] Layout guard checks pass across all 6,270 simulated viewport configurations without clipping or overflow.

### Runtime Stability & Studio Certification
- [ ] Roblox Studio playtest boots cleanly with zero unhandled exceptions, script execution timeouts, or runtime soft-locks.
- [ ] Mobile touch gestures and console gamepad navigation register accurately across all interactive panels.
