# Testing

`tests/interaction_tests.gd` exercises real physics overlaps with the player scene: forward/backward selection, camera turns, hysteresis, prompt changes, marker position, input locking, one interaction per press, disabled/freed targets and shipping-style eligibility. It is included in `tests/test_runner.gd`.

Manual check: stand between garden beds and turn the camera; the diamond and action prompt should agree and remain stable through small movements. Walk to a shop counter, open and close it, then carry a shipping crate to its destination. The marker should disappear during a menu and only offer actions permitted by the carried item. Repeat with the gamepad right stick and interact button.

Validation, 2026-11-27: all 15 focused interaction checks passed. Farm and shop screenshots checked marker visibility. A pre-existing credits-audio assertion failed in the full run because its wait only flushed two frames; the wait now allows the sound to finish, and the story-sound suite passed on rerun. The full regression run had 990 passing checks and two audio failures. Both were corrected and their suites passed on targeted reruns: story audio waits for playback to finish; background music cancels a previous fade before reusing its speaker. A new regression check confirms rapid region changes cannot stop the current track. Godot still reports resource leaks at shutdown.
