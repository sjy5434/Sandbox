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
// REVISION HISTORY:
//   v1 (first pass): hand-guessed proportions. Looked like a slender
//      torpedo/submarine with fins stuck on, not a koi - too tapered, too
//      laterally compressed, dorsal fin too shark-like.
//   v1 (this pass): rebuilt from pixel measurements taken directly off a
//      reference image (reference/koi_reference.webp, a 6-angle koi render).
//      The reference was thresholded against its flat gray background to
//      isolate the fish silhouette in the side and top views, then the
//      body's top/bottom/left/right edges were sampled column-by-column to
//      get real width/height-vs-length curves instead of guesses. See
//      reference/measure_koi.py for the measurement script. Key corrections
//      this produced:
//        - Body stays close to full depth almost all the way to the tail
//          (depth only drops to ~53% of max at the peduncle) instead of
//          tapering down to a thin torpedo tail (previously ~15-19%).
//        - Cross-section is nearly round (height ~= width, ratio ~1.04),
//          not the noticeably taller-than-wide ellipse used before.
//        - Dorsal fin is longer and lower (spans ~42%-76% of body length,
//          peak only ~22% of body depth) rather than a tall shark-fin
//          triangle.
//        - Tail fin is proportionally much larger (nearly as tall as the
//          body is deep).
//        - Added pelvic and anal fins (the reference clearly has them;
//          they just don't break the pure-side-view silhouette because
//          they tuck against the belly curve).
//
// SHAPE APPROACH:
//   The body is a "sphere loft": an array of stations runs from the nose
//   (x=0) to the end of the tail peduncle (x=body_length). At each station
//   a sphere is scaled into an ellipse (independent width/height) per a
//   hand-tuned profile curve (profile_at), and consecutive stations are
//   connected with hull() to form a smooth continuous body. Fins (dorsal,
//   pectoral, pelvic, anal, caudal/tail) are separate 2D profiles, thin-
//   extruded and unioned onto the body - all one solid at the end.
// ============================================================================

/* [Overall size - small single-object test] */
body_length = 70;    // nose to end of tail peduncle (mm) - excludes tail fin
max_width   = 30;    // body width at its widest point (mm)
max_height  = 32;    // body height at its widest point (mm) - koi are nearly round in cross-section, not strongly compressed

/* [Tail fin] */
tail_length    = 26;   // length of the caudal fin past the peduncle (mm)
tail_fin_thick = 2.0;  // thickness of the tail fin (mm)
tail_fork      = 0.30; // 0 = flat/rounded tail, higher = deeper forked tail - reference shows a shallow, gentle fork

/* [Dorsal fin] */
dorsal_start_t  = 0.42; // fraction of body_length where the dorsal fin begins
dorsal_end_t    = 0.76; // fraction of body_length where the dorsal fin ends
dorsal_height   = 7;    // how far the dorsal fin rises above the back (mm) - measured ~22% of body depth
dorsal_thick    = 1.6;  // fin thickness (mm)

/* [Pectoral fins - just behind the head] */
pectoral_t        = 0.27; // fraction of body_length where pectoral fins attach
pectoral_length   = 13;   // fin length (mm)
pectoral_width    = 9;    // fin width (mm)
pectoral_thick    = 1.6;  // fin thickness (mm)
pectoral_droop    = 45;   // degrees the fin angles downward from horizontal
pectoral_sweep    = 15;   // degrees the fin sweeps backward

/* [Pelvic fins - belly, below the front of the dorsal fin] */
pelvic_t      = 0.44;
pelvic_length = 10;
pelvic_width  = 7;
pelvic_thick  = 1.4;
pelvic_droop  = 60;
pelvic_sweep  = 10;

/* [Anal fin - single fin, belly, near the tail] */
anal_t      = 0.80;
anal_length = 7;
anal_height = 6;
anal_thick  = 1.3;

/* [Body loft resolution] */
body_stations = 48; // number of hull segments along the body - higher = smoother, slower render

/* [Head details] */
eye_t          = 0.065; // fraction of body_length where the eyes sit - measured close behind the nose
eye_r          = 2.2;   // eye bump radius (mm)
include_barbels = true; // koi/carp have small mouth barbels - thin (0.8mm dia) and delicate, disable if your printer can't resolve them
barbel_len     = 6;     // barbel length (mm)
barbel_r       = 0.4;   // barbel radius (mm)

$fn = 32;

// ---------------------------------------------------------------------------
// Body profile: key points (t, width_scale, height_scale) measured from the
// reference image's side-view silhouette (t=0 nose, t=1 end of peduncle,
// scales are fractions of max_width/max_height). Smoothly interpolated with
// cosine easing. See reference/measure_koi.py for how these were derived.
// ---------------------------------------------------------------------------
profile_keys = [
    [0.00, 0.05, 0.05],  // nose tip
    [0.03, 0.30, 0.30],  // blunt rounded nose fills out fast
    [0.065, 0.46, 0.46], // eye line
    [0.13, 0.65, 0.65],
    [0.20, 0.78, 0.78],
    [0.26, 0.85, 0.85],
    [0.33, 0.91, 0.91],
    [0.45, 0.99, 0.99],  // widest point (shoulder)
    [0.60, 0.97, 0.96],
    [0.72, 0.80, 0.80],
    [0.79, 0.72, 0.72],
    [0.86, 0.66, 0.66],
    [0.92, 0.58, 0.58],
    [1.00, 0.53, 0.55],  // peduncle - stays notably thick right up to the tail fin
];

function ease(f) = (1 - cos(180 * f)) / 2; // cosine smoothstep, f in [0,1]
function lerp(a, b, f) = a + (b - a) * f;

function seg_interp(t, a, b) =
    let(f = ease((t - a[0]) / (b[0] - a[0])))
    [lerp(a[1], b[1], f), lerp(a[2], b[2], f)];

// Piecewise interpolation across profile_keys via recursion (works for any key count).
function profile_at(t, i = 0) =
    (i >= len(profile_keys) - 1) ? [profile_keys[i][1], profile_keys[i][2]] :
    (t <= profile_keys[i][0]) ? [profile_keys[i][1], profile_keys[i][2]] :
    (t <= profile_keys[i + 1][0]) ? seg_interp(t, profile_keys[i], profile_keys[i + 1]) :
    profile_at(t, i + 1);

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
// (x = body_length). Sized close to body depth per the reference image.
// ---------------------------------------------------------------------------
module tail_fin() {
    tip_h = max_height * 0.85;
    base_r = half_height(1.0) * 1.05;
    lobe_offset = tip_h * 0.52;
    lobe_r = lobe_offset * 1.08; // overlapping lobes so hull() alone has no inherent notch - fork depth comes entirely from the wedge cut below
    lobe_x = tail_length * 0.76;

    // Wedge that starts well beyond the lobes' own extent (guaranteeing it
    // breaches the trailing edge, whatever lobe_r/lobe_x end up being) and
    // points inward to notch_apex_x - depth controlled by tail_fork
    // (0 = rounded single fan, 1 = deep fork).
    hull_max_x = lobe_x + lobe_r;
    notch_apex_x = lerp(hull_max_x * 0.92, lobe_x * 0.5, tail_fork);
    notch_half_w = lobe_offset * 0.42;
    wedge_x = hull_max_x * 1.5;

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
                        [wedge_x, notch_half_w],
                        [notch_apex_x, 0],
                        [wedge_x, -notch_half_w],
                    ]);
                }
}

// ---------------------------------------------------------------------------
// Dorsal fin: smooth rounded sail (hull of three circles) along the back -
// long, low, gently domed - matches the measured ~22%-of-body-depth peak
// rather than a tall shark-fin triangle. Base embedded slightly into the
// back so it bonds cleanly.
// ---------------------------------------------------------------------------
module dorsal_fin() {
    x0 = dorsal_start_t * body_length;
    x1 = dorsal_end_t * body_length;
    x_peak = x0 + 0.42 * (x1 - x0);
    base_z0 = half_height(dorsal_start_t) - 1.5;
    base_z1 = half_height(dorsal_end_t) - 1.5;
    peak_z = max(half_height(dorsal_start_t), half_height(dorsal_end_t)) + dorsal_height;
    r_base = 2.4;
    r_peak = 2.2;

    rotate([90, 0, 0])
        linear_extrude(height = dorsal_thick, center = true)
            hull() {
                translate([x0, base_z0]) circle(r = r_base, $fn = 20);
                translate([x_peak, peak_z]) circle(r = r_peak, $fn = 20);
                translate([x1, base_z1]) circle(r = r_base, $fn = 20);
            }
}

// ---------------------------------------------------------------------------
// Paired side fins (pectoral and pelvic share this shape, different size/
// placement/angle): small fan fin, angled outward/downward, mirrored.
// ---------------------------------------------------------------------------
module side_fin_one_side(t, length, width, thick, droop, sweep) {
    x = t * body_length;
    y = half_width(t) - 1;
    points = [
        [0, -width * 0.3],
        [length, 0],
        [0, width * 0.7],
    ];
    translate([x, y, 0])
        rotate([droop, 0, sweep])
            linear_extrude(height = thick, center = true)
                polygon(points = points);
}

module side_fin_pair(t, length, width, thick, droop, sweep) {
    side_fin_one_side(t, length, width, thick, droop, sweep);
    mirror([0, 1, 0]) side_fin_one_side(t, length, width, thick, droop, sweep);
}

module pectoral_fins() {
    side_fin_pair(pectoral_t, pectoral_length, pectoral_width, pectoral_thick, pectoral_droop, pectoral_sweep);
}

module pelvic_fins() {
    side_fin_pair(pelvic_t, pelvic_length, pelvic_width, pelvic_thick, pelvic_droop, pelvic_sweep);
}

// ---------------------------------------------------------------------------
// Anal fin: single small fin on the belly centerline, near the tail
// ---------------------------------------------------------------------------
module anal_fin() {
    x0 = anal_t * body_length;
    x1 = x0 + anal_length;
    base_z = -half_height(anal_t) + 1;
    tip_z = base_z - anal_height;

    rotate([90, 0, 0])
        linear_extrude(height = anal_thick, center = true)
            polygon(points = [
                [x0, base_z],
                [x1, base_z + (tip_z - base_z) * 0.3],
                [x0 + anal_length * 0.3, tip_z],
            ]);
}

// ---------------------------------------------------------------------------
// Eyes: small proud bumps on either side of the head
// ---------------------------------------------------------------------------
module eyes() {
    x = eye_t * body_length;
    y = half_width(eye_t) * 0.88;
    z = half_height(eye_t) * 0.25;
    translate([x, y, z]) sphere(r = eye_r, $fn = 16);
    translate([x, -y, z]) sphere(r = eye_r, $fn = 16);
}

// ---------------------------------------------------------------------------
// Barbels: thin whisker-like feelers near the mouth (a distinguishing koi/
// carp feature). Thin and delicate - controlled by include_barbels.
// ---------------------------------------------------------------------------
module barbels() {
    x = 0.015 * body_length;
    y = half_width(0.02) * 0.5;
    z = -half_height(0.02) * 0.3;
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
        pelvic_fins();
        anal_fin();
        eyes();
        if (include_barbels) barbels();
    }
}

koi_v1();
