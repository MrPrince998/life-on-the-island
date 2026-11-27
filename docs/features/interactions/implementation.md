# Implementation

`PlayerInteraction` in `scripts/player/player_interaction.gd` ranks the existing overlap candidates using `CameraRig.get_yaw()`, applies `FACING_WEIGHT` and `SWITCH_MARGIN`, and owns one reusable Label3D focus marker. No meshes or shared materials are modified. Prompts still update through GameManager only when the selection or text changes.

`Interactable.get_focus_position()` returns the exported local `focus_offset` transformed into world space. The default is 2 metres above the area; individual props can override it without changing the selection logic.

Disabled and freed targets are excluded. Shipping's `can_interact_now()` rules and hands-busy restrictions are preserved. Action input refreshes and validates focus before using it, then refreshes after interactions that lock the player or remove the target. No save format changes.
