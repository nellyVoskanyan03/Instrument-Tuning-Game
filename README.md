# Instrument-Tuning-Game
## Overview
This project implements a simple FPGA-based music game.  
The system detects musical notes from a microphone input and moves a player across the screen when the played note matches the expected one.  
The game displays visual feedback on an LCD screen and note information on 7-segment displays.

## Features
- Note detection (C, D, E, F, G, A, B) based on microphone input.
- Real-time visual feedback on LCD.
- Player movement controlled by both keys and detected notes.
- Collision detection and LED indication.
- 7-segment display showing expected and detected notes.

## Note Detection
- Measures time between microphone signal transitions to estimate frequency.
- Compares measured period with expected note frequencies:
  - C: 26163 Hz
  - D: 29366 Hz
  - E: 32963 Hz
  - F: 34923 Hz
  - G: 39200 Hz
  - A: 44000 Hz
  - B: 49388 Hz
- Uses timing windows for frequency matching with octave scaling (×4, ×2, ×1).
- Stable detection is confirmed after consistent readings.

## Game Logic
- Player moves between columns (stairs) when the correct note is played.
- Collision detection prevents movement into obstacles.
- When the player reaches the right edge of the screen, the background turns green.

## Visual Elements
- Player: red square (16×16).
- Obstacles: black columns.
- Background: white.
- Screen resolution: 480×272.

## 7-Segment Display
- Left digit: expected note.
- Right digit: detected note.

## LED Indicator
- `led[0]` = 1 when collision detected.

## Notes
- Designed for FPGA boards like Tang Nano 9K or DE0-Nano.
- Can be used as an educational demo for note detection and FPGA graphics.
