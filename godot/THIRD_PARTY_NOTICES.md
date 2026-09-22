# Asset and data notices

## Original models and audio

The active three VEH_* GT models and environment/circuit_kit assets are original procedural Blender meshes. Editable sources and generators are included in art/source_blender and tools/blender. Cars are fictional, unbranded designs. Engine, tyre, kerb, impact and cue sounds are synthesized by scripts/engine_audio.gd; no commercial game audio is included.

## Circuit centre lines — MIT

Source: https://github.com/bacinger/f1-circuits
Copyright (c) 2019-2025 Tomislav Bacinger. Full MIT notice is retained at ../art/reference_data/LICENSE-f1-circuits.md and assets/circuits/LICENSE-f1-circuits.md. Geographic centre lines are projected to metres and smoothed.

## Venue database — OpenStreetMap / ODbL

© OpenStreetMap contributors. Source: https://www.openstreetmap.org/copyright
Open Database License 1.0: https://opendatacommons.org/licenses/odbl/1-0/
The derived venue database in assets/circuits/real_circuits.json contains transformed building, woodland and pit-lane features and is made available under ODbL 1.0. The original OSM data is publicly available through the OSM API; tools/fetch-venue-features.ps1 and tools/build-circuit-data.py reproduce the transformation. Source snapshots were fetched in September 2026. The accompanying original software and meshes are separate works.

## Elevation

SRTM30m data served by OpenTopoData: https://www.opentopodata.org/datasets/srtm/
SRTM originated with NASA/NGA. These public elevation data provide terrain samples, not surveyed road elevations. Height interpolation and a road-clearance adjustment are applied by the build script.

## Historical fallback

Kenney Car Kit: https://kenney.nl/assets/car-kit — Kenney, CC0 1.0 (https://creativecommons.org/publicdomain/zero/1.0/). assets/cars/sedan-sports.glb is retained as an inactive historical fallback. Its colormap was embedded for portable import.

## References only

The user's Bilibili video https://www.bilibili.com/video/BV1UrYy6ZEu4/ informs stylization and lighting. ACC and DREDGE inform the brief; none of their assets are distributed. Vehicle specification references and reconstruction limits are documented in ../art/README.md. There is no manufacturer or circuit endorsement, licensed branding, or laser-scan accuracy claim.
