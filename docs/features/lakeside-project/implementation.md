# Implementation

The scene `scenes/world/lakeside_project.tscn` is instanced in the island's lake story places. It reuses branch, flower, bench and seagull assets. `scripts/world/lakeside_project.gd` coordinates progress and `lakeside_action.gd` provides contextual bench and invitation actions. Existing `StoryActivity` nodes handle clearing animations and time.

Permanent completion and orientation use GameManager flags. The persistent save key `lakeside_project` stores absolute `birds_due` minutes and `reward_day`; a load applies overdue wildlife changes. Visits are deliberately transient. `Villager.begin_shared_activity()` temporarily overrides the schedule, and `end_shared_activity()` restores the current scheduled entry.

The fishing controller's real `catch_finished` signal drives rewards. Oliver accompanies and reacts to the player's fishing; he does not run a separate fishing simulation. The existing daily friendship service enforces the normal heart cap.
