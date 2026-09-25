// ============================================================================
// koi_joint_test.scad
//
// Small test piece for an articulating koi fish: two tapered body segments
// joined by a PRINT-IN-PLACE ball-and-socket joint, plus a separate raised
// scale layer for dual-color (AMS) printing.
//
// PRINT ORIENTATION (do not rotate before slicing):
//   The model is built with the joint axis along Z and the socket cavity
//   opening UPWARD (segment B at the bottom, its socket facing +Z; the ball
//   and segment A sit above it). Printing with this orientation as-is is
//   what lets the ball's equator/upper hemisphere print without support:
//   each layer of the ball is closely nested inside a matching ring of the
//   socket wall, separated only by `joint_clearance`, so the gap is bridged
//   layer-by-layer instead of needing an overhang support structure. Do NOT
//   lay the model on its side in the slicer, or the ball will need supports
//   that fuse into the socket cavity.
//
// Two independent top-level solids are emitted (never unioned together):
//   - base_body()   : the printable body (both tapered segments + joint)
//   - scales_layer(): raised scale bumps, sitting exactly on the body's
//                      outer surface, for assigning to a second AMS slot.
//
// Render/export selection is controlled by the `render_part` variable below,
// which can be overridden from the command line with -D, e.g.:
//   openscad -D 'render_part="body"'   -o joint_test_body.stl   koi_joint_test.scad
//   openscad -D 'render_part="scales"' -o joint_test_scales.stl koi_joint_test.scad
// ============================================================================

/* [Articulation - tune these after the first test print] */
joint_clearance = 0.3;   // gap (mm) between ball and socket surfaces
seg_length      = 25;    // length (mm) of each tapered body segment
diam_large      = 18;    // large-end diameter (mm) of each segment
diam_small      = 14;    // small-end (joint-side) diameter (mm) of each segment

/* [Joint geometry - secondary tunables] */
ball_d        = 11;    // ball diameter (mm)
neck_d        = 6;     // diameter (mm) of the rigid rod connecting segment A to the ball
opening_extra = 2.5;   // how much wider than the neck the socket's top opening starts (mm)
opening_flare = 4;     // extra widening (mm) of the opening toward the top, for range of motion
socket_wall   = 1.8;   // wall thickness (mm) of the socket housing around the ball cavity

/* [Scale texture - parametric] */
scale_size      = 3;     // scale footprint length along the body (mm)
scale_width     = 0.7;   // scale width as a fraction of scale_size
scale_height    = 0.4;   // how far scales sit proud of the base body surface (mm)
scale_spacing_v = 2.2;   // vertical spacing between scale rows (mm) - less than scale_size so rows overlap
scale_spacing_a = 3.0;   // approx. arc spacing between scales within a row (mm)

/* [Render control] */
render_part = "both"; // "both" | "body" | "scales"  (override with -D on the command line)

$fn = 64;

// ---------------------------------------------------------------------------
// Derived dimensions
// ---------------------------------------------------------------------------
ball_r    = ball_d / 2;
neck_r    = neck_d / 2;
opening_r = neck_r + joint_clearance + opening_extra / 2;
housing_r = ball_r + joint_clearance + socket_wall;

z_ball      = seg_length;              // height of the ball/socket center (top of segment B's taper)
neck_len    = housing_r + 2;           // neck rod length from ball center to above the housing dome
neck_top_z  = z_ball + neck_len;       // height where segment A's tapered body begins

// ---------------------------------------------------------------------------
// Generic helper: rotate children so their local +Z axis aligns with vector v
// ---------------------------------------------------------------------------
module align_to(v) {
    vn = v / norm(v);
    zaxis = [0, 0, 1];
    d = zaxis * vn;
    if (d > 0.999999) {
        children();
    } else if (d < -0.999999) {
        rotate([180, 0, 0]) children();
    } else {
        ax = cross(zaxis, vn);
        ang = acos(d);
        rotate(a = ang, v = ax) children();
    }
}

// ---------------------------------------------------------------------------
// BASE BODY: segment B (bottom) + socket housing + ball/neck + segment A (top)
// ---------------------------------------------------------------------------
module tapered_body(len, d1, d2) {
    cylinder(h = len, d1 = d1, d2 = d2, $fn = 64);
}

module base_body() {
    union() {
        // Segment B: tapered body with the socket housing carved into its top
        difference() {
            union() {
                tapered_body(seg_length, diam_large, diam_small);
                translate([0, 0, z_ball]) sphere(r = housing_r, $fn = 64);
            }
            // Ball clearance cavity (full sphere so the ball is caged, not just resting in a bowl)
            translate([0, 0, z_ball]) sphere(r = ball_r + joint_clearance, $fn = 64);
            // Upward-facing opening for the neck rod; flares outward near the top for swing range
            translate([0, 0, z_ball])
                cylinder(h = neck_len + 5, r1 = opening_r, r2 = opening_r + opening_flare, $fn = 48);
        }

        // Ball + neck, rigidly part of segment A, sitting inside B's cavity with clearance on all sides
        translate([0, 0, z_ball]) sphere(r = ball_r, $fn = 64);
        translate([0, 0, z_ball]) cylinder(h = neck_len, r = neck_r, $fn = 48);

        // Segment A: tapered body above the neck
        translate([0, 0, neck_top_z]) tapered_body(seg_length, diam_small, diam_large);
    }
}

// ---------------------------------------------------------------------------
// SCALE LAYER: separate solid, raised scale_height above the base body surface
// ---------------------------------------------------------------------------
module scale_bump() {
    // Half-ellipsoid ("half-moon") dome: flat base at z=0 sits exactly on the
    // body's tangent plane at each grid point, dome rises +scale_height above it.
    intersection() {
        scale([scale_size / 2, (scale_size * scale_width) / 2, scale_height])
            sphere(r = 1, $fn = 16);
        translate([-100, -100, 0]) cube([200, 200, 200]);
    }
}

// Places one scale on a cone of local slope m (dr/dz) at azimuth theta and height z_local,
// with the cone's local radius r_local at that height.
module place_bump(theta, z_local, r_local, m) {
    pos = [r_local * cos(theta), r_local * sin(theta), z_local];
    normal = [cos(theta), sin(theta), -m];
    translate(pos) align_to(normal) scale_bump();
}

// Generates a diagonal (staggered) grid of scales over a tapered segment of length `len`
// whose radius goes from r1 (z=0) to r2 (z=len).
module gen_scales(len, r1, r2) {
    m = (r2 - r1) / len;
    margin = scale_size * 0.6;
    usable = len - 2 * margin;
    num_rows = floor(usable / scale_spacing_v);
    for (row = [0 : num_rows - 1]) {
        z = margin + row * scale_spacing_v;
        r_local = r1 + m * z;
        circumference = 2 * PI * r_local;
        num_cols = max(6, floor(circumference / scale_spacing_a));
        theta_step = 360 / num_cols;
        offset = (row % 2 == 0) ? 0 : theta_step / 2;
        for (col = [0 : num_cols - 1]) {
            theta = col * theta_step + offset;
            place_bump(theta, z, r_local, m);
        }
    }
}

module scales_layer() {
    union() {
        // Scales on segment B (bottom, large->small going up)
        gen_scales(seg_length, diam_large / 2, diam_small / 2);
        // Scales on segment A (top, small->large going up) - joint knuckle left bare
        translate([0, 0, neck_top_z]) gen_scales(seg_length, diam_small / 2, diam_large / 2);
    }
}

// ---------------------------------------------------------------------------
// Output selection
// ---------------------------------------------------------------------------
if (render_part == "body") {
    base_body();
} else if (render_part == "scales") {
    scales_layer();
} else {
    base_body();
    color("Orange") scales_layer();
}
