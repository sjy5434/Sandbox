# Koi Fish Joint Test Piece

A small OpenSCAD test print for an articulating koi fish: two tapered body
segments joined by a print-in-place ball-and-socket joint, with a separate
raised scale layer for dual-color printing on the AMS.

## Files

- `koi_joint_test.scad` — the parametric model.
- `export/joint_test_body.stl` — base body (both segments + joint), color 1.
- `export/joint_test_scales.stl` — raised scale layer, color 2.
- `export/koi_joint_test.3mf` — combined export (see note below on why the
  two STLs are the reliable path).

## Why two STLs instead of one 3MF

OpenSCAD 2021.01's built-in 3MF exporter flattens the design to a single mesh
— it does not preserve separate "objects" inside one 3MF the way Bambu
Studio needs in order to expose two paintable parts. So the reliable
workflow is:

1. In Bambu Studio, **Import** both `joint_test_body.stl` and
   `joint_test_scales.stl` into the same project.
2. They will already be aligned (both were exported from the same
   coordinate system in the .scad file — don't move one without the other).
3. Right-click each part → assign it to a different AMS filament slot
   (e.g. body → slot 1, scales → slot 2).
4. Group/arrange as needed, but keep their relative position fixed so the
   scale layer still sits flush on the body surface.

If you'd rather have a single file, Bambu Studio can merge the two STLs into
one project and re-export as a `.3mf` itself — that project-level 3MF *does*
preserve the two objects/paint assignments, unlike OpenSCAD's exporter.

## Print orientation

**Print it exactly as modeled — joint axis vertical (Z), no rotation in the
slicer.** The socket cavity opens upward by design:

- Segment B (bottom) tapers 18→14 mm and has the ball-cage/socket carved
  into its top.
- The ball (attached to segment A) sits inside that cage with a uniform
  `joint_clearance` (0.3 mm default) gap on all sides.
- Segment A (top) tapers 14→18 mm, connected to the ball by a short neck rod
  that passes up through a flared opening in the socket's top.

Because the opening faces up, the ball's equator and upper hemisphere print
as a series of closely-nested rings right next to the matching socket wall,
separated only by the clearance gap. That gap is small enough to bridge
layer-by-layer, so **no internal supports are needed inside the joint
cavity**. Do not lay the part on its side — that reintroduces a real
overhang on the ball and will force supports that fuse into the socket.

No supports are needed anywhere else on the part either (the tapered bodies
and scale bumps are all self-supporting/shallow-angle geometry). Standard
0.2 mm layer height should be fine; if your printer/filament tends to blob
on bridges, consider dropping to 0.16 mm around the joint region only.

## Build volume sanity check

With the default parameters:

- Total height ≈ 25 (segment B) + ~11.6 (joint/neck region) + 25 (segment A)
  ≈ **61.6 mm**
- Max diameter ≈ **18 mm** (the large end of each segment; the joint knuckle
  bulges to ~15.2 mm, still under the segment's max diameter)

That's a footprint on the order of 18 × 18 mm and ~62 mm tall — trivially
within the Bambu Lab A1 mini's 180 × 180 × 180 mm build volume, whether you
print it standing up (as recommended) or need to reorient for some other
reason.

## Judging `joint_clearance` after the test print

Print with the default `joint_clearance = 0.3` mm first, then adjust based
on what you see:

**Too tight (fused / won't move):**
- The joint doesn't rotate at all, or takes visible force and grinds/creaks.
- You see witness marks or torn strands where the ball and socket surfaces
  touched and welded together during printing.
- Twisting it further shows white stress marks or the neck rod flexing
  instead of the ball rotating.
- Fix: increase `joint_clearance` in 0.05–0.1 mm steps (try 0.35, then 0.4)
  and reprint.

**Too loose (sloppy articulation):**
- The ball rattles inside the socket or has noticeable play/wobble beyond
  just rotating.
- You can see daylight/gap around the ball when viewed from the side at the
  equator, well beyond a thin uniform line.
- The joint flops under the segment's own weight instead of holding a pose.
- Fix: decrease `joint_clearance` in 0.05 mm steps (try 0.25, then 0.2) and
  reprint. Very fine-detail printers/filaments (e.g. well-tuned PETG or ABS)
  can often go tighter than PLA before fusing.

**Good result:** the joint rotates smoothly with light, consistent
resistance in every direction, holds a pose against gravity, and shows no
fused/torn surface texture when you look inside the visible neck opening.

Other parameters worth revisiting once clearance is dialed in:
- `opening_extra` / `opening_flare` control how much the ball can swing
  before the neck rod hits the socket's opening wall — widen these if you
  want more range of motion once the base friction is right.
- `scale_size`, `scale_spacing_v`, `scale_spacing_a`, `scale_height` control
  the scale texture density/relief and can be tuned independently of the
  joint.
