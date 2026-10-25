class_name TyreModel
## Steady-state tyre force curves (simplified Pacejka "magic formula").
## The lateral curve is normalised so its peak equals effective_mu * load at PEAK_SLIP_ANGLE.

const PEAK_SLIP_ANGLE := 0.09
const PEAK_SLIP_RATIO := 0.10
## Fraction of peak friction a fully sliding (locked or spinning) tyre still delivers.
const SLIDE_FACTOR := 0.80

# B solved numerically so the C=1.9 / E=0.6 curve peaks at PEAK_SLIP_ANGLE.
# E was lowered from the plan's 0.97 so grip falls to ~81% at 0.25 rad
# instead of ~96%: a slide past the peak has to cost something.
const LAT_B := 14.67
const LAT_C := 1.9
const LAT_E := 0.6

const LOAD_REF := 4000.0
const LOAD_SENSITIVITY := 0.08


static func pacejka(x: float, b: float, c: float, d: float, e: float) -> float:
	var bx := b * x
	return d * sin(c * atan(bx - e * (bx - atan(bx))))


static func effective_mu(mu: float, load_n: float) -> float:
	return mu * clampf(1.0 - LOAD_SENSITIVITY * (load_n / LOAD_REF - 1.0), 0.75, 1.1)


static func lateral_force(slip_angle: float, load_n: float, mu: float) -> float:
	return lateral_with_peak(slip_angle, effective_mu(mu, load_n) * load_n)


## Lateral force when the caller already knows the peak force (grip with load
## sensitivity applied); the curve only supplies the shape.
## Past the peak the curve never drops below SLIDE_FACTOR: a tyre sliding sideways
## still has sliding friction, the same as a locked or spinning one.
static func lateral_with_peak(slip_angle: float, peak_force: float) -> float:
	var y := pacejka(slip_angle, LAT_B, LAT_C, 1.0, LAT_E)
	if absf(slip_angle) > PEAK_SLIP_ANGLE:
		y = signf(slip_angle) * maxf(absf(y), SLIDE_FACTOR)
	return y * peak_force
