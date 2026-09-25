// ============================================================================
// koi_body_v1.scad
//
// Project roadmap (this file is Step 1):
//   1. THIS FILE: small, single-object, single-color koi silhouette. Proves
//      out the body shape (fusiform profile, head, fins, tail) before any
//      articulation or texture is added.
//   2. Scale this body up and split it into an articulating multi-segment
//      version (still single color), reusing the same profile curve.
//   3. Print just the head + first body segment to test the joint(s) from
//      step 2 in isolation before committing to a full-length print.
//   4. Add a separate, second-color scale layer modeled as overlapping
//      koi-scale shapes (not the generic bump grid from the earlier joint
//      test) that follow the body surface from step 2/3.
//
// This step is intentionally NOT articulated and has NO scale texture yet.
// It is one continuous, single manifold solid (single AMS color).
//
// SHAPE APPROACH:
//   The body is a "sphere loft": an array of stations runs from the nose
//   (x=0) to the end of the tail peduncle (x=body_length). At each station
//   a sphere is scaled into an ellipse (independent width/height) per a
//   hand-tuned profile curve (profile_at), and consecutive stations are
//   connected with hull() to form a smooth continuous body. Fins (dorsal,
//   pectoral, caudal/tail) are separate 2D profiles, thin-extruded and
//   unioned onto the body — all one solid at the end.
// ============================================================================

/* [Overall size - small single-object test] */
body_length = 60;   // nose to end of tail peduncle (mm) - excludes tail fin
max_width   = 14;   // body width at its widest point (mm)
max_height  = 17;   // body height at its widest point (mm) - taller than wide (laterally compressed), like a real fish

/* [Tail fin] */
tail_length    = 20;   // length of the caudal fin past the peduncle (mm)
tail_fin_thick = 1.4;  // thickness of the tail fin (mm)
tail_fork      = 0.35; // 0 = flat/rounded tail, higher = deeper forked tail

/* [Dorsal fin] */
dorsal_start_t  = 0.30; // fraction of body_length where the dorsal fin begins
dorsal_end_t    = 0.62; // fraction of body_length where the dorsal fin ends
dorsal_height   = 7;    // how far the dorsal fin rises above the back (mm)
dorsal_thick    = 1.3;  // fin thickness (mm)

/* [Pectoral fins] */
pectoral_t        = 0.20; // fraction of body_length where pectoral fins attach
pectoral_length   = 10;   // fin length (mm)
pectoral_width    = 6;    // fin width (mm)
pectoral_thick    = 1.2;  // fin thickness (mm)
pectoral_droop    = 35;   // degrees the fin angles downward from horizontal
pectoral_sweep    = 20;   // degrees the fin sweeps backward

/* [Body loft resolution] */
body_stations = 48; // number of hull segments along the body - higher = smoother, slower render

/* [Head details] */
eye_t          = 0.09;  // fraction of body_length where the eyes sit
eye_r          = 1.3;   // eye bump radius (mm)
include_barbels = true; // koi/carp have small mouth barbels - thin (0.8mm dia) and delicate, disable if your printer can't resolve them
barbel_len     = 4;     // barbel length (mm)
barbel_r       = 0.4;   // barbel radius (mm)

$fn = 32;

// ---------------------------------------------------------------------------
// Body profile: hand-tuned key points (t, width_scale, height_scale), t in [0,1]
// along the body from nose (t=0) to end of peduncle (t=1). Scales are
// fractions of max_width/max_height. Smoothly interpolated with cosine easing.
// ---------------------------------------------------------------------------
profile_keys = [
    [0.00, 0.16, 0.16],  // rounded nose tip
    [0.05, 0.55, 0.58],  // head widens quickly
    [0.15, 0.85, 0.84],  // behind the gill area
    [0.35, 1.00, 0.97],  // widest point (shoulder)
    [0.55, 0.90, 0.88],
    [0.75, 0.55, 0.57],  // tapering toward the tail
    [0.90, 0.32, 0.34],
    [1.00, 0.15, 0.19],  // narrow peduncle just before the tail fin
];

function ease(f) = (1 - cos(180 * f)) / 2; // cosine smoothstep, f in [0,1]
function lerp(a, b, f) = a + (b - a) * f;

function seg_interp(t, a, b) =
    let(f = ease((t - a[0]) / (b[0] - a[0])))
    [lerp(a[1], b[1], f), lerp(a[2], b[2], f)];

function profile_at(t) =
    t <= profile_keys[0][0] ? [profile_keys[0][1], profile_keys[0][2]] :
    t >= profile_keys[7][0] ? [profile_keys[7][1], profile_keys[7][2]] :
    t <= profile_keys[1][0] ? seg_interp(t, profile_keys[0], profile_keys[1]) :
    t <= profile_keys[2][0] ? seg_interp(t, profile_keys[1], profile_keys[2]) :
    t <= profile_keys[3][0] ? seg_interp(t, profile_keys[2], profile_keys[3]) :
    t <= profile_keys[4][0] ? seg_interp(t, profile_keys[3], profile_keys[4]) :
    t <= profile_keys[5][0] ? seg_interp(t, profile_keys[4], profile_keys[5]) :
    t <= profile_keys[6][0] ? seg_interp(t, profile_keys[5], profile_keys[6]) :
    seg_interp(t, profile_keys[6], profile_keys[7]);

function half_width(t)  = profile_at(t)[0] * max_width  / 2;
function half_height(t) = profile_at(t)[1] * max_height / 2;

// ---------------------------------------------------------------------------
// Body: sphere-loft along X
// ---------------------------------------------------------------------------
module body_station(t) {
    x = t * body_length;
    w = max(half_width(t), 0.05);
    h = max(half_height(t), 0.05);
    translate([x, 0, 0])
        scale([0.6, w, h])
            sphere(r = 1, $fn = 28);
}

module fish_body() {
    for (i = [0 : body_stations - 1]) {
        t0 = i / body_stations;
        t1 = (i + 1) / body_stations;
        hull() {
            body_station(t0);
            body_station(t1);
        }
    }
}

// ---------------------------------------------------------------------------
// Tail (caudal) fin: smooth, gently forked fan (rounded lobes, not sharp
// zigzag), built as a hull of circles with a rounded notch subtracted from
// the trailing edge. Thin-extruded, attached at the end of the peduncle
// (x = body_length).
// ---------------------------------------------------------------------------
module tail_fin() {
    tip_h = max_height * 0.65;
    base_r = half_height(1.0) * 1.05;
    lobe_r = tip_h * 0.42;
    lobe_offset = tip_h * 0.55;
    lobe_x = tail_length * 0.78;

    // Wedge that starts beyond the fin tip (guaranteeing it breaches the
    // trailing edge) and points inward to notch_apex_x - depth controlled
    // by tail_fork (0 = nearly rounded single fan, 1 = deep fork).
    notch_apex_x = lerp(tail_length * 0.98, lobe_x * 0.55, tail_fork);
    notch_half_w = lobe_offset * 0.7;

    translate([body_length, 0, 0])
        rotate([90, 0, 0])
            linear_extrude(height = tail_fin_thick, center = true)
                difference() {
                    hull() {
                        circle(r = base_r, $fn = 32);
                        translate([lobe_x, lobe_offset]) circle(r = lobe_r, $fn = 32);
                        translate([lobe_x, -lobe_offset]) circle(r = lobe_r, $fn = 32);
                    }
                    polygon(points = [
                        [tail_length * 1.2, notch_half_w],
                        [notch_apex_x, 0],
                        [tail_length * 1.2, -notch_half_w],
                    ]);
                }
}

// ---------------------------------------------------------------------------
// Dorsal fin: smooth rounded sail (hull of three circles) along the back -
// steep-ish leading edge, long low trailing edge, no sharp shark-fin corners.
// Base embedded slightly into the back so it bonds cleanly.
// ---------------------------------------------------------------------------
module dorsal_fin() {
    x0 = dorsal_start_t * body_length;
    x1 = dorsal_end_t * body_length;
    x_peak = x0 + 0.4 * (x1 - x0);
    base_z0 = half_height(dorsal_start_t) - 1.5;
    base_z1 = half_height(dorsal_end_t) - 1.5;
    peak_z = max(half_height(dorsal_start_t), half_height(dorsal_end_t)) + dorsal_height;
    r_base = 2.2;
    r_peak = 1.8;

    rotate([90, 0, 0])
        linear_extrude(height = dorsal_thick, center = true)
            hull() {
                translate([x0, base_z0]) circle(r = r_base, $fn = 20);
                translate([x_peak, peak_z]) circle(r = r_peak, $fn = 20);
                translate([x1, base_z1]) circle(r = r_base, $fn = 20);
            }
}

// ---------------------------------------------------------------------------
// Pectoral fins: small flat fins near the head, angled outward/downward,
// mirrored to both sides
// ---------------------------------------------------------------------------
module pectoral_fin_one_side() {
    x = pectoral_t * body_length;
    y = half_width(pectoral_t) - 1;
    points = [
        [0, -pectoral_width * 0.3],
        [pectoral_length, 0],
        [0, pectoral_width * 0.7],
    ];
    translate([x, y, 0])
        rotate([pectoral_droop, 0, pectoral_sweep])
            linear_extrude(height = pectoral_thick, center = true)
                polygon(points = points);
}

module pectoral_fins() {
    pectoral_fin_one_side();
    mirror([0, 1, 0]) pectoral_fin_one_side();
}

// ---------------------------------------------------------------------------
// Eyes: small proud bumps on either side of the head
// ---------------------------------------------------------------------------
module eyes() {
    x = eye_t * body_length;
    y = half_width(eye_t) * 0.82;
    z = half_height(eye_t) * 0.15;
    translate([x, y, z]) sphere(r = eye_r, $fn = 16);
    translate([x, -y, z]) sphere(r = eye_r, $fn = 16);
}

// ---------------------------------------------------------------------------
// Barbels: thin whisker-like feelers near the mouth (a distinguishing koi/
// carp feature). Thin and delicate - controlled by include_barbels.
// ---------------------------------------------------------------------------
module barbels() {
    x = 0.015 * body_length;
    y = half_width(0.02) * 0.55;
    z = -half_height(0.02) * 0.25;
    translate([x, y, z]) rotate([0, 100, 0]) cylinder(r = barbel_r, h = barbel_len, $fn = 8);
    translate([x, -y, z]) rotate([0, 100, 0]) cylinder(r = barbel_r, h = barbel_len, $fn = 8);
}

// ---------------------------------------------------------------------------
// Full koi, single solid
// ---------------------------------------------------------------------------
module koi_v1() {
    union() {
        fish_body();
        tail_fin();
        dorsal_fin();
        pectoral_fins();
        eyes();
        if (include_barbels) barbels();
    }
}

koi_v1();
