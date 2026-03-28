shader_type spatial;
render_mode unshaded, cull_back;

// ── Matcap ──────────────────────────────────────────────────────────
// A warm-cool matcap created procedurally (no texture needed).
// Upper hemisphere → warm highlight, lower → cool shadow.
uniform vec3 color_top     : source_color = vec3(0.92, 0.92, 0.95);  // bright highlight
uniform vec3 color_mid     : source_color = vec3(0.62, 0.64, 0.68);  // mid-tone
uniform vec3 color_bottom  : source_color = vec3(0.22, 0.23, 0.27);  // shadow
uniform float matcap_contrast : hint_range(0.5, 3.0) = 1.4;

// ── Cavity ──────────────────────────────────────────────────────────
// Screen-space curvature: darkens concavities, lightens convexities.
uniform float cavity_strength : hint_range(0.0, 3.0) = 1.2;
uniform float cavity_ridge    : hint_range(0.0, 2.0) = 0.35;   // ridge highlight

// ── Fresnel rim ─────────────────────────────────────────────────────
uniform float rim_power   : hint_range(0.5, 8.0) = 3.0;
uniform float rim_strength : hint_range(0.0, 1.0) = 0.25;
uniform vec3  rim_color   : source_color = vec3(0.75, 0.78, 0.85);

varying vec3 v_normal_view;

void vertex() {
	// Transform normal into view space for matcap look-up and cavity calc.
	v_normal_view = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	// ── 1.  Matcap (procedural, hemisphere ramp) ────────────────────
	vec3 N = normalize(v_normal_view);

	// Use the Y component of the view-space normal as the "matcap" coordinate.
	// +Y = up in screen → lit, -Y = down → shadow.
	float mc = N.y * 0.5 + 0.5;                     // 0..1
	mc = pow(mc, 1.0 / matcap_contrast);             // contrast tweak

	// Three-stop gradient: bottom → mid → top.
	vec3 matcap;
	if (mc < 0.5) {
		matcap = mix(color_bottom, color_mid, mc * 2.0);
	} else {
		matcap = mix(color_mid, color_top, (mc - 0.5) * 2.0);
	}

	// Add a subtle highlight lobe from the upper-right (fake "sun" direction).
	float sun_dot = dot(N, normalize(vec3(0.35, 0.7, 0.55)));
	float sun_lobe = pow(max(sun_dot, 0.0), 4.0) * 0.25;
	matcap += sun_lobe * color_top;

	// ── 2.  Screen-space cavity ────────────────────────────────────
	// Approximate curvature from the screen-space derivatives of the
	// view-space normal.  Concavities → negative curvature → darken,
	// convexities / ridges → positive curvature → lighten.
	vec3 dNdx = dFdx(N);
	vec3 dNdy = dFdy(N);
	float curvature = (dot(dNdx, dNdx) + dot(dNdy, dNdy));
	curvature = sqrt(curvature);

	// Signed curvature: cross-product trick to separate cavity from ridge.
	float cavity_sign = dNdx.x + dNdy.y;  // divergence of normal field
	float cavity   = max(-cavity_sign, 0.0) * cavity_strength;
	float ridge    = max( cavity_sign, 0.0) * cavity_ridge;

	// Blend cavity darkening and ridge highlighting.
	vec3 shaded = matcap;
	shaded *= mix(1.0, 0.3, clamp(cavity * 6.0, 0.0, 1.0));  // darken cavities
	shaded += ridge * 3.0 * color_top * 0.5;                    // lighten ridges

	// ── 3.  Fresnel rim ────────────────────────────────────────────
	float fresnel = pow(1.0 - abs(N.z), rim_power);
	shaded = mix(shaded, rim_color, fresnel * rim_strength);

	// ── Output ─────────────────────────────────────────────────────
	ALBEDO = shaded;
}
