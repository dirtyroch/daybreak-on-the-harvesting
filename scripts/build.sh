#!/usr/bin/env bash
# Builds DaybreakOnTheHarvesting.rbxlx: Rojo puts in the code, then Lune bakes the map geometry
# into Workspace so you can see the arena in Studio before pressing Play.
set -euo pipefail
cd "$(dirname "$0")/.."
rojo build default.project.json -o DaybreakOnTheHarvesting.rbxlx
lune run scripts/bake-map DaybreakOnTheHarvesting.rbxlx
