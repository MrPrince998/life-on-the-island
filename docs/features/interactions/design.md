# Clear interaction targets

**Status:** implemented

Within the existing interaction reach, prefer the object in the camera's horizontal facing direction. Mouse look and the gamepad's right stick use the same selection. Nearby objects behind the player remain available when they are the only choice.

The score is horizontal distance plus up to 3 metres of facing penalty; objects within 0.35 metres have no facing penalty. Keep the current eligible target unless a competitor improves its score by more than 0.2 metres. This prevents flicker at the boundary between nearby objects.

Show a warm outlined diamond at the selected object's focus point and the existing action prompt at the bottom of the screen. The marker remains readable over foreground geometry, including the character. It disappears while the player is busy, sitting, or without a valid target. The stand-up prompt remains available while sitting. Targeting costs no game time.

Missing watering cans point to the garden shed by the farm gate. Before shipping begins, the packing table explains that the first orders arrive tomorrow morning. Field prompts already direct players to Bram for hoes and cutting tools.

History: 2026-11-27 — camera-directed selection, stable focus and contextual hints.
