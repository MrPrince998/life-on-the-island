# Testing

Automated coverage is in `tests/lakeside_tests.gd`, called by the main test runner: clearing prerequisites and costs, bench choice, missing rod, schedule override, nearby versus distant catch rewards, daily reward cap, visit end, save round trip, and overnight wildlife.

Manual check: follow the path north from the village toward the dock. Find “A quiet corner” just southwest of the dock. Clear each pile with E, choose one of the two labelled orientations, sit, then use the invitation sign. Meet Oliver at the dock and fish beside him. Sleep and return to see the birds. Continue a save to check the selected bench and cooldown.

Validation on 2026-11-25: all 20 focused checks passed with no script errors. Before/after renders checked the debris, signpost, bench, flowers and circling birds. The full regression suite passed all 786 checks with no script errors. Godot reports resource/renderer leaks at shutdown; these are separate from the gameplay assertions.
