extends "res://scripts/autoload/game.gd"
# Test-only: never writes a real profile, even without the CLI guard.
func save_profile() -> bool:
	return false
