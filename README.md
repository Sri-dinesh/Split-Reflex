<div align="center">
  <img src="assets/playstore_icon_512.png" width="160" height="160" alt="Split Reflex Icon" />
  <h1>SPLIT REFLEX</h1>
  <p><strong>A high-intensity, dual-hemisphere cognitive reflex arcade game built with Flutter.</strong></p>
</div>

## Overview

**Split Reflex** challenges neuro-motor coordination and divided attention by forcing the player's brain to simultaneously execute two completely independent cognitive mechanics across split screen hemispheres.

Every 15 seconds, the engine mutates: the split boundary drifts, hemisphere mechanics swap sides, polarities invert, and speeds accelerate.

---

## 3 Selectable Game Pairs (6 Unique Mechanics)

1. **CLASSIC**
   - **Left (Orb)**: Gravity-inverted vertical thruster navigating through descending laser gates and ceiling/floor spikes.
   - **Right (Dart)**: Precision horizontal rail-slider dodging falling monolith pillars via touch dragging or physical gyroscope tilt.

2. **PHASE FLUX**
   - **Left (Phase Core)**: Instant polarity-inverting core (*Cyan* ↔ *Crimson*). Must match incoming laser wall polarities to absorb energy instead of crashing.
   - **Right (Slalom Drift)**: Undulating sine-wave chasm glider navigating through a mathematically winding canyon with startup runway stabilization.

3. **TIDE LOCK**
   - **Left (Tide Valve + Submarine)**: One shared water level fills while the thumb holds and drains on release. The buoyant pressure hull rides just under the crest and must dive under descending hanging arches — starving the valve.
   - **Right (Harvester Buoy)**: Steered across the same surface; barnacle bulbs only feed while the tide is high enough to reach them, and urchin patrols roam the water column below. Two opposite tenants, one trigger.

---

## Key Features

- **Zero External Media Assets**: 100% procedural Canvas math rendering with custom shaders, CRT scanlines, and reactive bloom.
- **In-Memory Synthesized Audio**: Real-time procedural audio engine generating pure 16-bit PCM WAV buffers in memory (zero audio asset files).
- **Customizable Rulesets**:
  - **1-Hand vs 2-Hands**: Solo independent survival or mutual death rule.
  - **Solo vs Duo Co-Op**: Single-device dual-player mode with forensic blame autopsy attribution on death.
  - **Touch vs Gyro Tilt**: Smooth physical sensor-based tilt steering with low-pass dampening.
  - **4 Procedural Cyber Themes**: High-contrast Monochrome, Neon Synthwave, Matrix Terminal, and CyberGold.
- **Battery Overdrive Engine**: Dynamically senses device battery levels — unlocks 3x Overdrive under 10% battery and 10x God Mode at 1% battery.
- **Forensic Autopsy Receipts**: High-resolution receipt sharing card capturing exact survival time, mutation milestones, and battery status.

---

## Tech Stack & Architecture

- **Framework**: Flutter 3.x (Multiplatform: Android, iOS, Web)
- **State Management**: Riverpod (`flutter_riverpod`)
- **Graphics**: Hardware-accelerated `CustomPainter` with custom bloom pass, floating particle pools, and spring physics
- **Sensors & Platform**: `sensors_plus`, `battery_plus`, `vibration`, `share_plus`
- **Testing**: Complete unit and widget test suite (`flutter test`)
