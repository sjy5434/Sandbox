# Articulating Koi Fish — Project Roadmap

This project is being built in deliberate steps rather than all at once:

1. **`koi_body_v1.scad` (this step)** — a small, single-object, single-color
   koi silhouette. No articulation, no scale texture. The goal is just to
   get the body/fin shape right before anything else is layered on.
2. Scale this body up and split it into an articulating multi-segment
   version (still single color), reusing the same body profile curve.
3. Print just the head + first body segment to test the joint(s) from step 2
   in isolation before committing to a full-length print.
4. Add a separate, second-color scale layer modeled as overlapping koi-scale
   shapes (not a generic bump grid) that follow the body surface from step
   2/3, for dual-color AMS printing.

A standard koi and a butterfly koi (longer fins) variant are both planned for
later once the base body/joint design is solid.

## This step: `koi_body_v1.scad`

A single continuous manifold solid: fusiform (torpedo-shaped, laterally
compressed) body built as a "sphere loft" along the spine, plus a smooth
gently-forked tail fin, a rounded sail-like dorsal fin, two angled pectoral
fins, small proud eyes, and optional thin mouth barbels (a koi/carp
identifier).

### How the body shape works

`profile_keys` defines a handful of (position-along-body, width-scale,
height-scale) control points from nose to tail peduncle — blunt rounded
nose, quick widening through the head/gills, widest at the "shoulder,"
gradual taper into a narrow peduncle. `profile_at(t)` cosine-interpolates
between them. `fish_body()` walks along the spine placing a squashed sphere
(ellipsoid) at each station per that profile and `hull()`s each consecutive
pair, producing one smooth continuous surface — no discrete segments yet
(that comes in step 2).

Fins are built the same way conceptually: 2D outlines (as `hull()`s of
circles, or a couple of extra shape tricks) linear-extruded to a thin
constant thickness, then rotated/positioned onto the body. The tail fin's
notch is cut with a wedge polygon that starts beyond the fin's own tip
(guaranteeing it actually breaches the outer edge) rather than a circle
sitting mid-fin, which is what produced an isolated hole in an earlier
draft.

### Key parameters (top of the file)

- `body_length`, `max_width`, `max_height` — overall body size.
- `tail_length`, `tail_fork` — tail fin length and how deeply forked it is
  (0 ≈ single rounded fan, 1 ≈ deep fork).
- `dorsal_start_t` / `dorsal_end_t` / `dorsal_height` — where the dorsal fin
  sits along the body and how tall it stands.
- `pectoral_t`, `pectoral_droop`, `pectoral_sweep` — pectoral fin placement
  and angle.
- `include_barbels` — the mouth barbels print as ~0.8 mm-diameter whiskers;
  disable this if your nozzle/printer can't resolve them cleanly.
- `body_stations` — resolution of the body loft (higher = smoother + slower
  to render).

### Geometry check

Exported to `export/koi_body_v1.stl` and independently verified:
- OpenSCAD's own render report: `Simple: yes` (2D-manifold), 2 volumes (the
  single connected solid + the unbounded exterior — expected for one
  connected body).
- `trimesh`: `is_watertight: True`, `is_winding_consistent: True`.

### Size

Bounding box ≈ 81 mm (L, including tail fin) × 17.7 mm (W, including
pectoral fins) × 27.6 mm (H, including the dorsal fin) — well within the
Bambu Lab A1 mini's 180×180×180 mm build volume.

### Printing this step

This step is just a shape check, not the articulation test — print it lying
on its side (as it naturally rests) for the least overhang: the belly is the
flattest, lowest part of the profile. The dorsal fin and tail lobes will
want light support material since they're thin vertical fins sticking up
off the body when laid on its side; that's expected and fine for a
single-color shape-proofing print. Articulation/joint printing concerns
come in step 3.
