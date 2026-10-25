# OverCut GP — Plan 1: Núcleo de simulación y conducción

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Un proyecto Godot 4.7.2 con la física completa de un F1 de 2012 (neumático, compuestos, temperatura, desgaste, superficies, agua, aerodinámica, motor V8 + KERS + DRS, muros) conducible en un circuito de pruebas con teclado, mando y táctil, con vibración, y cubierto por tests headless.

**Architecture:** La simulación es GDScript puro (`RefCounted`/`Resource`, sin `RigidBody2D`), a paso fijo de 120 Hz con 4 subpasos, determinista y testeable sin ventana. El render (Node2D) solo lee el estado. El neumático usa un modelo de "fuerza demandada limitada por fricción" con curvas Pacejka y elipse de fricción, con estados explícitos de bloqueo y patinaje, porque un modelo con rotación de rueda integrada es inestable a baja velocidad a esta frecuencia.

**Tech Stack:** Godot 4.7.2 estándar (GDScript), runner de tests propio headless.

**Spec:** `docs/superpowers/specs/2026-10-25-overcut-gp-design.md` (secciones 3, 5, 6, 11 y 16).

## Hoja de ruta de la Fase 1 (temporada 2012): un plan por subsistema

1. **Núcleo de simulación y conducción** ← este plan
2. Pipeline de circuitos y los 20 trazados de 2012 (pit lane, DRS, sectores, decoración)
3. Datos de 2012 (equipos, pilotos, sustitutos, coches, colores, siluetas) y calibración del rendimiento (±1,5 % respecto a la pole real)
4. IA en 5 niveles y colisiones entre coches
5. Fin de semana: Q1/Q2/Q3 recortada, salida, reglas, boxes, banderas, SC, bandera roja, fiabilidad, daños, clima dinámico, puntos y campeonato
6. HUD 2004–2017, menús y responsive horizontal/vertical
7. Sonido V8 2012 y ambiente
8. I+D y monedas, guardado (Godot y Spring), exportación web e integración en los dos repos de OverCut

Cada plan se escribe cuando termina el anterior, usando sus interfaces reales.

## Global Constraints

- Motor: Godot 4.7.2 estándar, GDScript. Nada de C#/.NET.
- Exe de tests: `C:\Users\hugoe\AppData\Local\Programs\Godot\Godot_v4.7.2-stable_win64_console.exe`.
- Proyecto: `overcutf1/OvercutDespliegue/overcut/godot/overcut-gp/` dentro del repo `C:\Users\hugoe\Downloads\BackUp-OverCutServer` (rama `feature/overcut-gp-sim-core` creada desde `main`).
- Física a 120 Hz (`physics/common/physics_ticks_per_second=120`) con `SUBSTEPS = 4` internos. Unidades SI (m, kg, s, N, rad). Las velocidades en km/h solo aparecen en la UI y en los tests.
- La simulación no usa aleatoriedad global: cualquier ruido sale de funciones deterministas de la posición o de un RNG con semilla.
- La IA usará exactamente esta misma física (anti-objetivo del spec: nada de agarre extra).
- Sin logos, tipografías oficiales ni grabaciones reales.
- No ejecutar `react-scripts build` ni `mvn compile` (este plan no toca OverCut web).
- Los textos de la UI de depuración pueden ir en español. La UI final llega en el plan 6.

## Review Focus

1. **Coche parado sin input:** no debe deslizarse, girar ni vibrar (jitter a baja velocidad). → `test_at_rest_no_creep` (Task 7).
2. **Coche marcha atrás o de lado tras un trompo:** las fórmulas de deriva no deben dar NaN ni fuerzas explosivas con `vx≈0` o `vx<0`. → `test_spin_recovery_no_nan` (Task 7).
3. **dt grande o hitch de frames en móvil:** la simulación avanza a paso fijo y nunca integra un dt mayor que `TICK/SUBSTEPS`. → `test_large_frame_delta_is_substepped` (Task 11).
4. **Coche fuera de cualquier segmento del circuito** (atraviesa un muro a gran velocidad o queda lejos de la pista): `project()` no puede fallar y `wall_contact` debe empujarlo hacia dentro. → `test_far_outside_track_is_wall_and_pushes_inside` (Task 8).
5. **Varios toques táctiles a la vez** (acelerar y girar con dos dedos, o un dedo que se desliza fuera del botón): cada dedo conserva su control hasta que se levanta. → `test_multitouch_finger_keeps_its_control` (Task 9).

---

## Estructura de archivos

Raíz: `overcutf1/OvercutDespliegue/overcut/godot/overcut-gp/`

| Archivo | Responsabilidad |
|---|---|
| `project.godot`, `.gitignore` | Proyecto, 120 Hz, input map |
| `tests/test_case.gd`, `tests/run_tests.gd` | Runner headless |
| `sim/units.gd` | Constantes y conversiones |
| `sim/tyre/tyre_compound.gd`, `sim/tyre/tyre_compounds.gd` | Datos de compuestos 2012 |
| `sim/tyre/tyre_model.gd` | Pacejka y elipse de fricción |
| `sim/tyre/tyre_state.gd` | Temperatura, desgaste y factor de agarre de cada rueda |
| `sim/track/surface.gd` | Tabla de superficies |
| `sim/track/track_data.gd`, `sim/track/track_geometry.gd`, `sim/track/track_projection.gd` | Datos del circuito y consultas espaciales |
| `sim/track/test_track_builder.gd` | Circuito de pruebas sintético |
| `sim/track/track_environment.gd` | Geometría y condiciones (temperatura, agua) |
| `sim/car/car_spec.gd` | Parámetros físicos (baseline de 2012) |
| `sim/car/powertrain.gd` | Motor, caja, KERS y DRS |
| `sim/car/car_state.gd`, `sim/car/wheel_state.gd` | Estado dinámico |
| `sim/car/vehicle_sim.gd` | Paso de dinámica |
| `sim/sim_clock.gd` | Paso fijo y acumulador |
| `input/driver_input.gd`, `input/input_mapper.gd`, `input/assists.gd`, `input/touch_controls.gd` | Entrada y ayudas |
| `platform/haptics_director.gd`, `platform/haptics_backend.gd` | Vibración |
| `render/track_mesh_builder.gd`, `render/shaders/*.gdshader`, `render/car_renderer.gd`, `render/chase_camera.gd` | Visual |
| `scenes/dev/test_drive.tscn`, `scenes/dev/test_drive.gd`, `scenes/dev/debug_overlay.gd`, `game/car_controller.gd` | Escena conducible |
| `tests/bench/bench_sim.gd` | Benchmark de 24 coches |

---

### Task 1: Proyecto y runner de tests

**Files:**
- Create: `project.godot`, `.gitignore`, `icon.svg`, `tests/test_case.gd`, `tests/run_tests.gd`, `tests/test_smoke.gd`
- Commit también: `docs/superpowers/specs/2026-10-25-overcut-gp-design.md` y este plan

**Interfaces:**
- Produces: `TestCase` (base de todo test) con `assert_true(cond: bool, msg := "")`, `assert_eq(a, b, msg := "")`, `assert_near(a: float, b: float, tol: float, msg := "")`, `assert_between(v: float, lo: float, hi: float, msg := "")`. El runner descubre `res://tests/**/test_*.gd` (excluyendo `tests/bench/`), instancia cada uno, llama a cada método `test_*` y registra los fallos sin abortar. Filtro opcional con `-- --filter=<substring>` sobre `archivo::método`. Termina con `quit(1)` si hay fallos y `quit(0)` si no. Imprime `PASS archivo::test`, `FAIL archivo::test — msg` y `N passed, M failed`.

- [ ] **Step 1:** `git checkout main && git checkout -b feature/overcut-gp-sim-core` en `C:\Users\hugoe\Downloads\BackUp-OverCutServer`.
- [ ] **Step 2:** Crear `project.godot` (nombre "OverCut GP", `config/features=PackedStringArray("4.7")`, `physics/common/physics_ticks_per_second=120`, `physics/common/max_physics_steps_per_frame=8`, renderer `gl_compatibility` porque es el que exporta a web y móvil) y `.gitignore` con `.godot/`, `*.import` NO (los `.import` sí se versionan), `export/`.
- [ ] **Step 3:** Escribir `tests/test_smoke.gd`:

```gdscript
extends TestCase
func test_runner_works() -> void:
	assert_eq(1 + 1, 2)
	assert_near(0.1 + 0.2, 0.3, 1e-9)
	assert_between(5.0, 1.0, 10.0)
```

- [ ] **Step 4:** Ejecutar `& $GODOT --headless --path <proyecto> --import`, y después `& $GODOT --headless --path <proyecto> --script res://tests/run_tests.gd`. Esperado: falla, porque aún no existe `TestCase`.
- [ ] **Step 5:** Implementar `tests/test_case.gd` (`class_name TestCase extends RefCounted`, con `var failures: Array[String]`) y `tests/run_tests.gd` (`extends SceneTree`, en `_initialize()`).
- [ ] **Step 6:** Volver a ejecutar. Esperado: `PASS test_smoke.gd::test_runner_works` y `1 passed, 0 failed`, con exit 0. Cambiar temporalmente `2` por `3` y confirmar exit 1, y después revertirlo.
- [ ] **Step 7:** Commit: `feat(overcut-gp): proyecto Godot y runner de tests headless` (añadir spec y plan).

En adelante, `$RUN` = `& "C:\Users\hugoe\AppData\Local\Programs\Godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path overcutf1/OvercutDespliegue/overcut/godot/overcut-gp --script res://tests/run_tests.gd`. Tras crear archivos con `class_name` nuevos, ejecutar antes `--import` una vez para que se registren las clases.

---

### Task 2: Compuestos de 2012 y modelo Pacejka

**Files:**
- Create: `sim/units.gd`, `sim/tyre/tyre_compound.gd`, `sim/tyre/tyre_compounds.gd`, `sim/tyre/tyre_model.gd`
- Test: `tests/sim/test_tyre_model.gd`

**Interfaces:**
- Produces:
  - `Units`: `const G := 9.81`, `const AIR_DENSITY := 1.225`, `static func kmh(ms: float) -> float`, `static func ms(kmh: float) -> float`.
  - `TyreCompound extends Resource`: `id: StringName`, `grip: float`, `temp_min: float`, `temp_max: float`, `wear_rate: float`, `cliff_wear: float`, `is_wet_tyre: bool`, `water_optimum: float`, `water_window: float`.
  - `TyreCompounds.get_compound(id: StringName) -> TyreCompound`, `TyreCompounds.DRY_2012 := [&"supersoft", &"soft", &"medium", &"hard"]`.
  - `TyreModel.PEAK_SLIP_ANGLE := 0.09`, `TyreModel.PEAK_SLIP_RATIO := 0.10`, `TyreModel.SLIDE_FACTOR := 0.80`, `static func pacejka(x: float, b: float, c: float, d: float, e: float) -> float`, `static func lateral_force(slip_angle: float, load_n: float, mu: float) -> float`, `static func effective_mu(mu: float, load_n: float) -> float` (sensibilidad a la carga: `mu * clamp(1.0 - 0.08 * (load_n / 4000.0 - 1.0), 0.75, 1.1)`).

Valores 2012 (tabla del spec; temperaturas en °C, `wear_rate` relativo al medio):

| id | grip | temp_min | temp_max | wear_rate | cliff_wear | wet | water_optimum | water_window |
|---|---|---|---|---|---|---|---|---|
| supersoft | 1.035 | 80 | 105 | 2.0 | 0.70 | no | 0.0 | 0.12 |
| soft | 1.020 | 85 | 110 | 1.4 | 0.72 | no | 0.0 | 0.12 |
| medium | 1.000 | 95 | 120 | 1.0 | 0.75 | no | 0.0 | 0.12 |
| hard | 0.985 | 105 | 130 | 0.75 | 0.78 | no | 0.0 | 0.12 |
| intermediate | 0.93 | 50 | 85 | 1.6 | 0.75 | sí | 0.35 | 0.30 |
| wet | 0.89 | 40 | 75 | 1.8 | 0.75 | sí | 0.80 | 0.45 |

El lateral usa Pacejka con `B = 1.9 / PEAK_SLIP_ANGLE * 0.6`, `C = 1.9` y `E = 0.97`, normalizado para que el pico valga exactamente `effective_mu * load` cerca de `PEAK_SLIP_ANGLE`. Los coeficientes se pueden reajustar si los tests lo exigen; documentarlo en el código.

- [ ] **Step 1: Test**

```gdscript
extends TestCase
func test_lateral_peak_near_peak_slip_angle() -> void:
	var f_peak := TyreModel.lateral_force(TyreModel.PEAK_SLIP_ANGLE, 4000.0, 1.7)
	assert_true(f_peak > TyreModel.lateral_force(0.05, 4000.0, 1.7))
	assert_true(f_peak > TyreModel.lateral_force(0.20, 4000.0, 1.7))
	assert_near(f_peak, 1.7 * 4000.0, 1.7 * 4000.0 * 0.03)
func test_lateral_falloff_after_peak() -> void:
	var f_peak := TyreModel.lateral_force(TyreModel.PEAK_SLIP_ANGLE, 4000.0, 1.7)
	assert_between(TyreModel.lateral_force(0.25, 4000.0, 1.7) / f_peak, 0.70, 0.95)
func test_lateral_is_odd_and_zero_at_zero() -> void:
	assert_near(TyreModel.lateral_force(0.0, 4000.0, 1.7), 0.0, 1e-6)
	assert_near(TyreModel.lateral_force(-0.07, 4000.0, 1.7), -TyreModel.lateral_force(0.07, 4000.0, 1.7), 1e-6)
func test_load_sensitivity_reduces_mu_at_high_load() -> void:
	assert_true(TyreModel.effective_mu(1.7, 9000.0) < TyreModel.effective_mu(1.7, 3000.0))
func test_compounds_2012_order() -> void:
	var g := TyreCompounds.DRY_2012.map(func(id): return TyreCompounds.get_compound(id).grip)
	assert_true(g[0] > g[1] and g[1] > g[2] and g[2] > g[3])
	assert_true(TyreCompounds.get_compound(&"wet").is_wet_tyre)
```

- [ ] **Step 2:** `$RUN -- --filter=tyre_model` → FAIL (clases sin definir).
- [ ] **Step 3:** Implementar los cuatro archivos con la tabla y las firmas.
- [ ] **Step 4:** `$RUN -- --filter=tyre_model` → todos PASS.
- [ ] **Step 5:** Commit `feat(overcut-gp): compuestos Pirelli 2012 y modelo Pacejka`.

---

### Task 3: Estado del neumático (temperatura, desgaste, agua)

**Files:**
- Create: `sim/tyre/tyre_state.gd`
- Test: `tests/sim/test_tyre_state.gd`

**Interfaces:**
- Consumes: `TyreCompound`, `TyreCompounds`.
- Produces: `TyreState extends RefCounted`: `compound: TyreCompound`, `temp_c: float`, `wear: float` (0 = nuevo, 1 = destruido), `laps: int`. Métodos: `static func fresh(compound_id: StringName, temp_c: float) -> TyreState`, `func grip_factor(water: float) -> float` (multiplicador sobre el mu base, que incluye `compound.grip`), y `func update(dt: float, slip_power_w: float, air_c: float, track_c: float, water: float) -> void`.

Reglas (las constantes de calor y enfriamiento se ajustan para cumplir los tests):
- **Temperatura:** dentro de la ventana el factor es 1.0. Fuera, `1 - 0.006 * grados_fuera`, con un mínimo de 0.6.
- **Desgaste:** `1 - 0.06 * wear` hasta `cliff_wear`, y a partir de ahí una caída adicional de `-1.2 * (wear - cliff_wear)`, con un mínimo de 0.35.
- **Agua** (`water` entre 0 y 1):
  - Slicks: `1 / (1 + 4.0 * max(0, water - 0.05))`.
  - Neumáticos de lluvia: máximo en `water_optimum` y una caída gaussiana con `water_window`. En seco se sobrecalientan y se gastan el triple.
- **Calor:** `temp += (slip_power_w * HEAT_K - (temp - lerp(track_c, air_c, 0.5)) * COOL_K * (1 + 6 * water)) * dt`.
- **Desgaste:** `wear += slip_power_w * WEAR_K * wear_rate * (2.0 if temp > temp_max else 1.0) * dt`.

- [ ] **Step 1: Test**

```gdscript
extends TestCase
func test_cold_tyre_has_less_grip() -> void:
	assert_true(TyreState.fresh(&"medium", 40.0).grip_factor(0.0) < TyreState.fresh(&"medium", 105.0).grip_factor(0.0) * 0.8)
func test_in_window_equals_compound_grip() -> void:
	assert_near(TyreState.fresh(&"soft", 95.0).grip_factor(0.0), 1.020, 1e-6)
func test_cliff_drops_grip() -> void:
	var t := TyreState.fresh(&"supersoft", 95.0); t.wear = 0.9
	assert_true(t.grip_factor(0.0) < 1.035 * 0.85)
func test_slicks_useless_in_heavy_water() -> void:
	var t := TyreState.fresh(&"medium", 105.0)
	assert_true(t.grip_factor(0.6) < t.grip_factor(0.0) * 0.5)
func test_inter_beats_slick_when_damp_and_loses_when_dry() -> void:
	var s := TyreState.fresh(&"soft", 95.0); var i := TyreState.fresh(&"intermediate", 70.0)
	assert_true(i.grip_factor(0.3) > s.grip_factor(0.3))
	assert_true(i.grip_factor(0.0) < s.grip_factor(0.0))
func test_wet_beats_inter_in_heavy_rain() -> void:
	assert_true(TyreState.fresh(&"wet", 60.0).grip_factor(0.8) > TyreState.fresh(&"intermediate", 70.0).grip_factor(0.8))
func test_sliding_heats_and_wears() -> void:
	var t := TyreState.fresh(&"medium", 60.0)
	for i in 600: t.update(1.0 / 120.0, 40000.0, 22.0, 30.0, 0.0)
	assert_true(t.temp_c > 80.0); assert_true(t.wear > 0.0)
func test_overheating_doubles_wear_rate() -> void:
	var a := TyreState.fresh(&"medium", 110.0); var b := TyreState.fresh(&"medium", 140.0)
	a.update(0.01, 30000.0, 22.0, 30.0, 0.0); b.update(0.01, 30000.0, 22.0, 30.0, 0.0)
	assert_near(b.wear / a.wear, 2.0, 0.05)
```

- [ ] **Step 2:** `$RUN -- --filter=tyre_state` → FAIL.
- [ ] **Step 3:** Implementar `TyreState`.
- [ ] **Step 4:** `$RUN -- --filter=tyre_state` → PASS.
- [ ] **Step 5:** Commit `feat(overcut-gp): temperatura, desgaste y agua por neumático`.

---

### Task 4: Superficies

**Files:**
- Create: `sim/track/surface.gd`
- Test: `tests/sim/test_surface.gd`

**Interfaces:**
- Produces: `Surface` con `enum Type { ASPHALT, RACING_LINE, KERB_LOW, KERB_HIGH, WHITE_LINE, GRASS, GRAVEL, RUNOFF_ASPHALT, PIT_LANE, WALL }`, `static func grip(type: int, water: float) -> float`, `static func rolling_resistance(type: int) -> float` (coeficiente adimensional sobre la carga), `static func bump(type: int) -> float` (0..1) y `static func is_off_track(type: int) -> bool` (GRASS, GRAVEL y WALL).

Tabla (grip en seco, grip con `water = 1`, rodadura, bump):

| tipo | seco | mojado | rodadura | bump |
|---|---|---|---|---|
| ASPHALT | 1.00 | 1.00 | 0.015 | 0.0 |
| RACING_LINE | 1.03 | 0.97 | 0.015 | 0.0 |
| KERB_LOW | 0.92 | 0.70 | 0.02 | 0.35 |
| KERB_HIGH | 0.78 | 0.55 | 0.05 | 0.9 |
| WHITE_LINE | 0.97 | 0.55 | 0.015 | 0.0 |
| GRASS | 0.45 | 0.30 | 0.12 | 0.4 |
| GRAVEL | 0.35 | 0.30 | 0.45 | 0.7 |
| RUNOFF_ASPHALT | 0.95 | 0.90 | 0.016 | 0.0 |
| PIT_LANE | 0.95 | 0.90 | 0.015 | 0.0 |
| WALL | 0.30 | 0.30 | 0.5 | 1.0 |

El efecto del agua que se describe aquí es solo el propio de la superficie (pintura, hierba). El efecto del agua sobre el neumático está en `TyreState`. Entre seco y mojado se interpola linealmente.

- [ ] **Step 1: Test:** `test_offtrack_low_grip` (GRASS y GRAVEL < 0.5 en seco), `test_gravel_high_rolling` (rodadura de GRAVEL ≥ 10 × ASPHALT), `test_wet_white_line_worse_than_dry_kerb` (`grip(WHITE_LINE, 1.0) < grip(KERB_LOW, 0.0)`), `test_interpolates_water` (`grip(WHITE_LINE, 0.5)` ≈ 0.76 ± 0.01) y `test_off_track_flags`.
- [ ] **Step 2:** `$RUN -- --filter=surface` → FAIL.
- [ ] **Step 3:** Implementar.
- [ ] **Step 4:** PASS.
- [ ] **Step 5:** Commit `feat(overcut-gp): tabla de superficies`.

---

### Task 5: Datos y geometría del circuito, y circuito de pruebas

**Files:**
- Create: `sim/track/track_data.gd`, `sim/track/track_projection.gd`, `sim/track/track_geometry.gd`, `sim/track/test_track_builder.gd`, `sim/track/track_environment.gd`
- Test: `tests/sim/test_track_geometry.gd`

**Interfaces:**
- Produces:
  - `TrackData extends Resource`:
    - `track_name: String`
    - `points: PackedVector2Array`: línea central cerrada en metros, separación ≤ 5 m y sin repetir el primer punto.
    - Arrays paralelos a `points`: `width_left` y `width_right` (PackedFloat32Array, del centro al borde del asfalto), `kerb_left` y `kerb_right` (ancho del piano en m, 0 si no hay), `kerb_high_left` y `kerb_high_right` (PackedByteArray, 1 si el piano es alto), `runoff_left` y `runoff_right` (PackedInt32Array con `Surface.Type`), y `wall_left` y `wall_right` (distancia del centro al muro, en m).
    - `func length() -> float`.
    - El plan 2 añadirá pit lane, DRS y sectores sin cambiar estos campos.
  - `TrackProjection extends RefCounted`: `s: float` (distancia recorrida desde el punto 0), `lateral: float` (positivo a la izquierda en sentido de marcha), `index: int`, `tangent: Vector2`.
  - `TrackGeometry extends RefCounted`:
    - `func _init(data: TrackData)` construye una rejilla espacial de segmentos con celdas de 25 m.
    - `func project(pos: Vector2) -> TrackProjection`. Si ninguna celda vecina tiene segmentos, busca por fuerza bruta; nunca devuelve null.
    - `func surface_at(pos: Vector2, racing_line_lateral := INF) -> int`. Las bandas, desde el centro: asfalto; una línea blanca de 0,12 m en el borde; piano (bajo o alto); runoff; y más allá del muro, WALL.
    - `func wall_contact(pos: Vector2, radius: float) -> Vector2`. Devuelve el vector de penetración hacia dentro de la pista (profundidad × normal), o `Vector2.ZERO`.
  - `TestTrackBuilder.build() -> TrackData`. Circuito de unos 3,2 km en sentido horario:
    - recta de 900 m;
    - horquilla de 15 m de radio con grava (`runoff = GRAVEL`, muro a 35 m);
    - "S" rápida de radios 180/160 m con hierba;
    - chicane con pianos altos;
    - curva de 90° de 40 m de radio con asfalto de escape.
    - Ancho de 12 m (6 + 6), pianos de 1,5 m y muros a 20 m salvo en la horquilla.
    - Se genera con arcos y rectas encadenados y se remuestrea cada 4 m.
  - `TrackEnvironment extends RefCounted`: `geometry: TrackGeometry` (null = plano infinito de asfalto), `air_c := 22.0`, `track_c := 32.0`, `water := 0.0`, `static func flat() -> TrackEnvironment`, `func surface_at(pos: Vector2) -> int`, `func water_at(pos: Vector2) -> float` (devuelve `water`; el plan 5 lo sustituirá por un campo de charcos).

- [ ] **Step 1: Test**

```gdscript
extends TestCase
var data := TestTrackBuilder.build()
var geo := TrackGeometry.new(data)
func test_length_about_3_2km() -> void:
	assert_between(data.length(), 3000.0, 3500.0)
func test_projection_on_centerline() -> void:
	var p := geo.project(data.points[100])
	assert_near(p.lateral, 0.0, 0.05); assert_eq(p.index, 100)
func test_projection_left_offset_positive() -> void:
	var t := (data.points[101] - data.points[100]).normalized()
	assert_near(geo.project(data.points[100] + t.orthogonal() * -3.0).lateral, 3.0, 0.1)  # orthogonal() rota -90°: comprobar el signo al implementar
func test_surface_bands() -> void:
	var c := data.points[50]; var n := (data.points[51] - c).normalized().orthogonal()
	assert_eq(geo.surface_at(c), Surface.Type.ASPHALT)
	assert_eq(geo.surface_at(c + n * (data.width_right[50] + 0.7)), Surface.Type.KERB_LOW)
	assert_eq(geo.surface_at(c + n * (data.width_right[50] + 4.0)), data.runoff_right[50])
	assert_eq(geo.surface_at(c + n * (data.wall_right[50] + 1.0)), Surface.Type.WALL)
func test_s_monotonic() -> void:
	assert_true(geo.project(data.points[200]).s > geo.project(data.points[100]).s)
func test_wall_contact_pushes_inside() -> void:
	var c := data.points[50]; var n := (data.points[51] - c).normalized().orthogonal()
	var push := geo.wall_contact(c + n * (data.wall_right[50] - 0.5), 1.0)
	assert_true(push.length() > 0.4 and push.dot(-n) > 0.0)
func test_query_performance() -> void:
	var t0 := Time.get_ticks_msec()
	for i in 10000: geo.surface_at(data.points[i % data.points.size()] + Vector2(3, 2))
	assert_true(Time.get_ticks_msec() - t0 < 400, "10k consultas < 400 ms")
```

(El test de Review Focus 4, `test_far_outside_track_is_wall_and_pushes_inside`, va en la Task 8.)

- [ ] **Step 2:** `$RUN -- --filter=track_geometry` → FAIL.
- [ ] **Step 3:** Implementar. La normal izquierda es `tangent.rotated(-PI/2)` en las coordenadas de Godot (y hacia abajo): fijar la convención una vez y ajustar el signo del test a ella, documentándolo en `track_projection.gd`.
- [ ] **Step 4:** PASS.
- [ ] **Step 5:** Commit `feat(overcut-gp): geometría de circuito y circuito de pruebas`.

---

### Task 6: Spec del coche de 2012 y tren motriz (V8, caja, KERS, DRS)

**Files:**
- Create: `sim/car/car_spec.gd`, `sim/car/powertrain.gd`
- Test: `tests/sim/test_powertrain.gd`

**Interfaces:**
- Produces:
  - `CarSpec extends Resource` con `static func baseline_2012() -> CarSpec` y estos campos y valores:

| campo | valor |
|---|---|
| `mass_kg` (coche + piloto, sin combustible) | 642.0 |
| `wheelbase` | 3.40 |
| `cg_to_front` | 1.84 (≈46 % de peso delante) |
| `track_front` / `track_rear` | 1.80 / 1.70 |
| `cg_height` | 0.30 |
| `yaw_inertia` | 1100.0 |
| `tyre_radius` | 0.33 |
| `max_steer` (rad, en la rueda) | 0.30 |
| `base_mu` | 1.70 |
| `max_power_kw` / `power_rpm` / `rev_limit` / `idle_rpm` | 560 / 17500 / 18000 / 4000 |
| `gear_ratios` (totales, 7 marchas) | [22.4, 17.4, 14.0, 11.6, 9.8, 8.3, 7.0] |
| `shift_time` | 0.04 |
| `drivetrain_eff` | 0.92 |
| `kers_power_kw` / `kers_energy_kj` | 60 / 400 |
| `cd_a` / `cl_a` / `aero_balance_front` | 1.25 / 4.2 / 0.44 |
| `drs_cd_a_delta` / `drs_cl_a_delta` | -0.16 / -0.50 |
| `brake_bias_front` | 0.56 |
| `max_brake_force_n` (suma de las 4 ruedas, por encima del límite de agarre) | 40000.0 |
| `fuel_capacity_kg` | 160.0 |

  - `Powertrain extends RefCounted`: `func _init(spec: CarSpec)`, `gear: int` (1..7, 0 = punto muerto), `rpm: float`, `kers_energy_j: float`, `func engine_torque(rpm: float, throttle: float) -> float` (curva de par plana desde unas 11.000 rpm, con potencia máxima en `power_rpm` y corte en el limitador), `func update_rpm(wheel_speed_ms: float) -> void`, `func drive_force(throttle: float, kers_request: bool, dt: float) -> float` (fuerza en el suelo en N, incluido el KERS hasta agotar la energía de la vuelta), `func auto_shift() -> void` (sube a 17.800 rpm y baja si al reducir quedan menos de 16.000 rpm), `func shift(dir: int) -> void`, `func reset_kers_lap() -> void`.

- [ ] **Step 1: Test:**
  - `test_peak_power_about_560kw`: la potencia máxima de `engine_torque × ω` en el rango de rpm queda entre 540 y 580 kW.
  - `test_limiter_cuts_torque`: `engine_torque(18100, 1)` ≈ 0.
  - `test_kers_lasts_about_6_7s`: con `kers_request = true` a plena potencia, la energía se agota entre 6,5 y 6,9 s, y después la fuerza extra es 0; `reset_kers_lap()` la restaura.
  - `test_auto_shift_up_near_limiter`.
  - `test_top_gear_speed_at_limiter`: en 7.ª a 18.000 rpm la velocidad queda entre 310 y 330 km/h.
- [ ] **Step 2:** `$RUN -- --filter=powertrain` → FAIL.
- [ ] **Step 3:** Implementar.
- [ ] **Step 4:** PASS.
- [ ] **Step 5:** Commit `feat(overcut-gp): spec F1 2012 y tren motriz V8 + KERS`.

---

### Task 7: Estado del coche y paso de dinámica en asfalto

**Files:**
- Create: `sim/car/wheel_state.gd`, `sim/car/car_state.gd`, `sim/car/vehicle_sim.gd`, `input/driver_input.gd`, `tests/helpers/sim_runner.gd`
- Test: `tests/sim/test_vehicle_dynamics.gd`

**Interfaces:**
- Consumes: `CarSpec`, `Powertrain`, `TyreState`, `TyreModel`, `Surface`, `TrackEnvironment`.
- Produces:
  - `DriverInput extends RefCounted`: `throttle`, `brake` (0..1), `steer` (-1..1, negativo = izquierda), `kers: bool`, `drs: bool`, `shift_up: bool`, `shift_down: bool`.
  - `WheelState extends RefCounted`: `tyre: TyreState`, `load_n`, `slip_angle`, `slip_ratio` (estimado), `sliding: bool`, `surface: int`, `fx`, `fy`.
  - `CarState extends RefCounted`: `position: Vector2`, `heading: float` (rad, 0 = +x), `velocity: Vector2` (mundo), `yaw_rate`, `steer_angle`, `fuel_kg`, `drs_open: bool`, `powertrain: Powertrain`, `wheels: Array[WheelState]` (0 = delantera izquierda, 1 = delantera derecha, 2 = trasera izquierda, 3 = trasera derecha), `last_impact_speed: float`, `distance_m: float`; `static func create(spec: CarSpec, compound_id: StringName, tyre_temp_c: float) -> CarState`; `func speed() -> float`; `func local_velocity() -> Vector2` (x hacia delante, y a la izquierda).
  - `VehicleSim`: `const SUBSTEPS := 4`, `static func step(state: CarState, spec: CarSpec, input: DriverInput, env: TrackEnvironment, dt: float) -> void`. Ejecuta `SUBSTEPS` subpasos de `dt / SUBSTEPS`.
  - `SimRunner` (helper de tests): `static func run(state, spec, env, seconds: float, input_fn: Callable) -> void`. Llama a `input_fn(state, t) -> DriverInput` en cada tick de 1/120 s.

Algoritmo de cada subpaso (aquí está la decisión de diseño; lo demás lo decide el implementador):
1. **Dirección:** `steer_angle` se mueve hacia `input.steer × max_steer` con una velocidad máxima de 2,5 rad/s.
2. **Cargas:** `peso` (con combustible) × reparto estático, más `downforce = 0.5 · ρ · v² · cl_a` repartida con `aero_balance_front`, más la transferencia longitudinal `m · ax_prev · h / L` y la lateral por eje `m · ay_prev · h / track × 0.5`. Se añade la oscilación de `Surface.bump` como `load *= 1 + 0.25 · bump · sin(distance_m · 1.7 + i)`, que es determinista. Las cargas nunca bajan de 0.
3. **Fuerza longitudinal demandada por rueda:** la tracción va a las traseras (reparto 50/50, diferencial abierto con bloqueo del 30 %, simplificado); el freno se reparte con `brake_bias_front`; la rodadura sale de `Surface.rolling_resistance`.
4. **Agarre disponible:** `avail = TyreModel.effective_mu(base_mu · tyre.grip_factor(water) · Surface.grip(surface, water), load) · load`.
5. **Saturación:** si `|Fx_demand| > avail`, la rueda pasa a `sliding`: `Fx = sign · avail · SLIDE_FACTOR` y la capacidad lateral queda en `sqrt(max(0, (avail · SLIDE_FACTOR)² − Fx²))`. Una delantera bloqueada no gira el coche. Si no, `Fx = demanda` y `Fy = lateral_force(slip_angle) · sqrt(1 − (Fx / avail)²)`.
6. **Ángulo de deriva:** `atan2(vy_rueda, max(|vx_rueda|, 1.0))` menos la dirección en las delanteras. Si `vx < 0` (marcha atrás tras un trompo) se usa `|vx|`, y la fuerza resultante se recorta a `avail`.
7. **Aerodinámica:** arrastre `0.5 · ρ · v² · (cd_a + drs_delta)` y rebufo (ganchos para el plan 4, con valor 1.0 aquí).
8. **Integración (Euler semi-implícito):** suma de fuerzas y momentos → aceleraciones → velocidad → posición. Se guardan `ax_prev` y `ay_prev`.
9. **Calor y desgaste:** `tyre.update` con `slip_power = |F| × velocidad de deslizamiento`. La velocidad de deslizamiento sale de `|vy_rueda|` y de la parte deslizante de `Fx` cuando la rueda está saturada (`|vx| · 0.15`).
10. **Parada:** con `speed < 0.3`, `throttle < 0.05` y freno o sin input, se anulan velocidad y `yaw_rate`.
11. **DRS:** `drs_open` solo si `input.drs` y no hay freno. Se cierra al frenar. En este plan no hay zonas; el plan 2 las restringirá.

- [ ] **Step 1: Test** (con `TrackEnvironment.flat()`, neumáticos medios a 105 °C, coche sin combustible salvo que se indique; `rec` es un pequeño recorder que guarda velocidad y yaw por tick):

```gdscript
extends TestCase
var spec := CarSpec.baseline_2012()
func _full(t := 1.0, d := false) -> Callable:
	return func(s, time): var i := DriverInput.new(); i.throttle = t; i.drs = d; return i
func test_top_speed_2012() -> void:
	var s := CarState.create(spec, &"medium", 105.0)
	SimRunner.run(s, spec, TrackEnvironment.flat(), 60.0, _full())
	assert_between(Units.kmh(s.speed()), 305.0, 330.0)
func test_drs_adds_top_speed() -> void:
	var a := CarState.create(spec, &"medium", 105.0); var b := CarState.create(spec, &"medium", 105.0)
	SimRunner.run(a, spec, TrackEnvironment.flat(), 60.0, _full())
	SimRunner.run(b, spec, TrackEnvironment.flat(), 60.0, _full(1.0, true))
	assert_between(Units.kmh(b.speed() - a.speed()), 8.0, 16.0)
func test_0_to_200_kmh() -> void:  # registrar el instante en que se superan los 200 km/h
	...  # assert_between(t200, 4.0, 6.0)
func test_braking_300_to_100() -> void:  # partir con velocity = 300 km/h, brake = 1
	...  # assert_between(distancia, 70.0, 130.0)
func test_cold_tyres_brake_longer() -> void:  # el mismo frenado con neumáticos a 40 °C
	...  # assert_true(dist_frio >= dist_caliente * 1.08)
func test_wet_slicks_brake_much_longer() -> void:  # env.water = 0.6
	...  # assert_true(dist_mojado >= dist_seco * 1.8)
func test_steady_state_lateral_g() -> void:  # helper: control PI del radio sobre un círculo; se sube la velocidad hasta perder el radio
	...  # R = 50 m: g entre 1.8 y 2.9; R = 300 m: g entre 3.8 y 5.6
func test_locked_fronts_lose_steering() -> void:  # 200 km/h, steer = 1: con brake = 1 frente a brake = 0.3
	...  # assert_true(giro_bloqueado < giro_trail_braking * 0.5)
func test_deterministic() -> void:  # dos ejecuciones de 20 s con la misma secuencia de input
	...  # assert_eq(a.position, b.position); assert_eq(a.heading, b.heading)
func test_at_rest_no_creep() -> void:  # 10 s sin input
	...  # assert_true(s.speed() < 0.01 and s.position.length() < 0.01 and abs(s.yaw_rate) < 1e-4)
func test_spin_recovery_no_nan() -> void:  # velocity a 30 m/s perpendicular al heading y yaw_rate = 3; 5 s con input aleatorio de semilla fija
	...  # comprobar en cada tick que posición y velocidad son finitas (is_finite) y speed < 100
func test_fuel_weight_slows_acceleration() -> void:  # fuel_kg = 150 frente a 0
	...  # assert_true(t200_lleno > t200_vacio * 1.1)
```

En los tests con `...`, el implementador escribe el bucle; las aserciones y los valores están fijados. Si un valor no entra en su rango, se ajustan las constantes del modelo (no los rangos), y se anota en el commit qué constante se movió.

- [ ] **Step 2:** `$RUN -- --filter=vehicle_dynamics` → FAIL.
- [ ] **Step 3:** Implementar `WheelState`, `CarState`, `DriverInput`, `VehicleSim` y `SimRunner` según el algoritmo.
- [ ] **Step 4:** `$RUN -- --filter=vehicle_dynamics` → PASS. Volver a ejecutar `$RUN` completo → todo PASS.
- [ ] **Step 5:** Commit `feat(overcut-gp): dinámica del vehículo con transferencia de carga, aero y elipse de fricción`.

---

### Task 8: Salirse de pista, pianos y muros

**Files:**
- Modify: `sim/car/vehicle_sim.gd` (superficie por rueda vía `env.surface_at(posición de la rueda)` y colisión con muros al final del subpaso)
- Test: `tests/sim/test_offtrack.gd`

**Interfaces:**
- Produces: `CarState.last_impact_speed` (componente normal de la velocidad en el último impacto, en m/s, que se pone a 0 al leerlo con `func consume_impact() -> float`) y `CarState.wall_contact: bool`. Radio de colisión del coche: 4 círculos de 0,55 m a lo largo del eje, en x = +2,2, +0,8, −0,8 y −2,2.

Respuesta al muro: se separa el coche por la penetración; la velocidad normal se refleja con una restitución de 0,25; la tangencial se reduce por fricción con `μ_muro = 0.4 × impulso normal`; y se añade un impulso de giro en el punto de contacto.

- [ ] **Step 1: Test** (sobre `TestTrackBuilder.build()`; posiciones derivadas de `points`, `width_*` y `wall_*` como en la Task 5):
  - `test_gravel_traps_car`: entrar en la grava de la horquilla a 150 km/h sin gas → a menos de 40 km/h en 60 m o menos.
  - `test_grass_decelerates_more_than_asphalt`: deceleración costeando por hierba > 3 × la de asfalto.
  - `test_high_kerb_destabilises`: varianza de `yaw_rate` con steer constante sobre KERB_HIGH a 200 km/h > 3 × la de asfalto.
  - `test_head_on_wall_stops_car`: a 150 km/h de frente contra el muro, la velocidad final queda por debajo de 35 km/h, el coche no atraviesa el muro (`project().lateral` dentro de `wall`) y `consume_impact()` > 30.
  - `test_glancing_wall_keeps_speed`: a 150 km/h con 10° de ángulo, la velocidad final es > 60 % de la inicial y el impacto queda entre 3 y 12 m/s.
  - `test_far_outside_track_is_wall_and_pushes_inside`: un coche colocado a 80 m del muro exterior → `surface_at` = WALL y, tras un tick, el coche está más cerca de la pista y sin NaN.
- [ ] **Step 2:** `$RUN -- --filter=offtrack` → FAIL.
- [ ] **Step 3:** Implementar.
- [ ] **Step 4:** `$RUN` completo → PASS.
- [ ] **Step 5:** Commit `feat(overcut-gp): superficies por rueda, pianos y colisión con muros`.

---

### Task 9: Entrada, ayudas y controles táctiles progresivos

**Files:**
- Create: `input/input_mapper.gd`, `input/assists.gd`, `input/touch_controls.gd`
- Modify: `project.godot` (input map: `throttle` = W/↑/RT, `brake` = S/↓/LT, `steer_left` = A/←/stick izquierdo −x, `steer_right` = D/→/stick izquierdo +x, `kers` = Espacio/A, `drs` = E/Y, `shift_up` = Q/RB, `shift_down` = Z/LB)
- Test: `tests/input/test_assists.gd`, `tests/input/test_touch.gd`, `tests/input/test_input_mapper.gd`

**Interfaces:**
- Produces:
  - `InputMapper extends RefCounted`:
    - `func read(state: CarState, dt: float, touch: TouchControls) -> DriverInput`. Combina las acciones del input map y el táctil, quedándose con el valor mayor.
    - Las entradas digitales (teclado) se suavizan con rampas: gas de 0 a 1 en 0,15 s, freno en 0,10 s y dirección en 0,20 s.
    - La dirección se atenúa con la velocidad para entrada digital o táctil: `steer *= lerp(1.0, 0.35, clamp(speed / 85.0, 0, 1))`. Con stick analógico no se atenúa, salvo con la opción `steer_assist`.
  - `Assists`:
    - `static func apply(input: DriverInput, state: CarState, spec: CarSpec, cfg: AssistConfig) -> DriverInput`.
    - `AssistConfig`: `traction_control`, `abs`, `auto_gearbox`, `steer_assist`, todos booleanos. `braking_line` es visual y llega en el plan 6.
    - El control de tracción reduce el gas cuando una trasera supera `slip_ratio > 0.12` o está `sliding`.
    - El ABS reduce el freno cuando una delantera está `sliding`.
  - `TouchControls extends Control`:
    - Cuatro zonas: izquierda y derecha para girar (abajo a la izquierda), freno y gas (abajo a la derecha).
    - `func pedal_value(local_y: float, height: float) -> float`: 0 en el borde inferior, 1 en el superior, con zona muerta de 0,08 y curva lineal.
    - `func steer_value(local_x: float, width: float, is_right: bool) -> float`: 0,35 en el borde interior y 1,0 en el exterior.
    - Lleva el control por índice de dedo (`InputEventScreenTouch` y `InputEventScreenDrag`): un dedo conserva su zona hasta que se levanta, aunque se deslice fuera.
    - `layout_scale` y `layout_offset` se pueden configurar.
    - Expone `throttle`, `brake` y `steer`.

- [ ] **Step 1: Test:**
  - `test_tc_prevents_rear_slide_in_wet`: gas a fondo desde 60 km/h con `water = 0.4`: con TC, ninguna trasera queda `sliding` más de 5 ticks seguidos; sin TC, sí.
  - `test_abs_prevents_front_lock`: frenada a fondo desde 250 km/h: con ABS no hay bloqueo sostenido de las delanteras; sin ABS, sí.
  - `test_keyboard_ramp`: el gas digital tarda en llegar a 1 entre 0,13 y 0,17 s.
  - `test_digital_steer_attenuated_at_speed`: a 80 m/s, la dirección completa por teclado queda entre 0,35 y 0,45.
  - `test_pedal_deadzone_and_progressive`: valores de `pedal_value` en y = 0,05h, 0,5h y 1,0h.
  - `test_multitouch_finger_keeps_its_control`: el dedo 0 pulsa gas y el dedo 1 gira a la izquierda; el dedo 0 se desliza hasta la zona de freno y sigue siendo gas; al levantar el dedo 1, la dirección vuelve a 0.
- [ ] **Step 2:** `$RUN -- --filter=input` → FAIL.
- [ ] **Step 3:** Implementar.
- [ ] **Step 4:** PASS.
- [ ] **Step 5:** Commit `feat(overcut-gp): mapeo de entrada, ayudas y táctil progresivo multitouch`.

---

### Task 10: Vibración (móvil y mando)

**Files:**
- Create: `platform/haptics_backend.gd`, `platform/haptics_director.gd`
- Test: `tests/platform/test_haptics.gd`

**Interfaces:**
- Consumes: `CarState` y `WheelState` (`surface`, `sliding`), `Surface.bump`, `CarState.consume_impact()`.
- Produces:
  - `HapticsBackend extends RefCounted`: `func pulse(strength: float, duration_ms: int) -> void`.
  - Implementación `WebHaptics`: si `OS.has_feature("web")`, usa `JavaScriptBridge.eval("navigator.vibrate && navigator.vibrate(%d)")`. En iOS no hace nada, y eso es aceptado.
  - Implementación `JoypadHaptics`: `Input.start_joy_vibration(device, weak, strong, duration_s)`. En web, si no surte efecto, recurre a `navigator.getGamepads()[i].vibrationActuator.playEffect("dual-rumble", {...})` vía `JavaScriptBridge`.
  - `RecordingHaptics` (para tests) guarda los pulsos.
  - `HapticsDirector extends RefCounted`: `enabled := true`, `func _init(backends: Array[HapticsBackend])`, `func update(state: CarState, input: DriverInput, dt: float) -> void`.
  - Eventos y patrones:
    - **Piano:** pulso de 25 ms con fuerza `0.3 + 0.6 × bump`, repetido cada `clamp(6.0 / speed, 0.04, 0.2)` s mientras haya alguna rueda en piano.
    - **Bloqueo:** pulso de 40 ms con fuerza 0,5 cada 0,08 s mientras haya una delantera `sliding` y `brake > 0.3`.
    - **Patinaje:** pulso de 30 ms con fuerza 0,4 cada 0,1 s mientras haya una trasera `sliding` y `throttle > 0.3`.
    - **Fuera de pista:** pulso de 50 ms con fuerza 0,6 cada 0,12 s.
    - **Impacto:** si `consume_impact() > 3`, un pulso único de `clamp(impacto / 25, 0.3, 1.0)` de fuerza y `80 + 4 × impacto` ms (máximo 300).
  - Limitador global: 70 ms como mínimo entre pulsos, salvo el impacto, que siempre pasa.

- [ ] **Step 1: Test** con `RecordingHaptics` y estados construidos a mano:
  - `test_kerb_pulses_scale_with_speed`: el número de pulsos en 1 s es mayor a 80 m/s que a 20 m/s.
  - `test_lock_pattern`.
  - `test_impact_always_fires_and_scales`.
  - `test_rate_limit_70ms`.
  - `test_disabled_emits_nothing`.
  - `test_no_pulses_on_clean_asphalt`.
- [ ] **Step 2:** FAIL.
- [ ] **Step 3:** Implementar.
- [ ] **Step 4:** PASS.
- [ ] **Step 5:** Commit `feat(overcut-gp): vibración por piano, bloqueo, patinaje, salidas e impactos`.

---

### Task 11: Render, cámara y escena conducible

**Files:**
- Create: `sim/sim_clock.gd`, `game/car_controller.gd`, `render/track_mesh_builder.gd`, `render/shaders/asphalt.gdshader`, `render/shaders/kerb.gdshader`, `render/shaders/gravel.gdshader`, `render/shaders/grass.gdshader`, `render/car_renderer.gd`, `render/chase_camera.gd`, `scenes/dev/test_drive.tscn`, `scenes/dev/test_drive.gd`, `scenes/dev/debug_overlay.gd`
- Test: `tests/game/test_sim_clock.gd`, `tests/game/test_test_drive_scene.gd`

**Interfaces:**
- Consumes: todo lo anterior.
- Produces:
  - `SimClock extends RefCounted`: `const TICK := 1.0 / 120.0`, `func advance(frame_dt: float) -> int` (número de ticks que toca simular; acumula el resto y nunca devuelve más de 8), `func alpha() -> float` (fracción para interpolar el render).
  - `CarController extends Node`: `spec: CarSpec`, `state: CarState`, `env: TrackEnvironment`, `input_source: Callable` (`(state, dt) -> DriverInput`), `assists: AssistConfig`, `haptics: HapticsDirector`. En `_physics_process(dt)` ejecuta `VehicleSim.step` una vez por tick de física, con el dt de 120 Hz.
  - `TrackMeshBuilder.build(data: TrackData) -> Node2D`. Genera polígonos por bandas con estos shaders:
    - hierba con franjas de corte;
    - runoff (grava con ruido granular, asfalto de escape más claro);
    - asfalto con ruido procedural y una banda de goma más oscura sobre la línea central desplazada (la trazada real llega en el plan 2);
    - línea blanca;
    - pianos con rayas rojas y blancas a lo largo de `s` (8 m por franja; los altos, más gruesos);
    - muros con `Line2D` gris y sombra.
  - `CarRenderer extends Node2D`: `primary: Color`, `secondary: Color`, `func _draw()`. Dibuja una silueta procedural de 2012 vista desde arriba, a escala real (5,0 × 1,8 m):
    - alerón delantero ancho de 1,8 m;
    - morro escalonado (ornitorrinco);
    - pontones;
    - cubierta motor con aleta;
    - alerón trasero estrecho de 0,75 m;
    - neumáticos negros, los traseros más anchos;
    - el casco del piloto.
    - Sombra desplazada. Los neumáticos delanteros giran con `steer_angle`.
  - `ChaseCamera extends Camera2D`:
    - Sigue al coche con suavizado.
    - **Rota con el coche (morro hacia arriba) por defecto**, que es decisión mía para facilitar el control táctil. Opción `north_up`.
    - El zoom se aleja con la velocidad: 9 px/m parado y 5 px/m a 300 km/h.
    - En vertical, el zoom se multiplica por 0,8.
  - **Escena `test_drive`:** circuito de pruebas, coche (rojo y blanco) a 20 m de la meta, entrada por teclado, mando y táctil, y vibración.
    - Overlay de depuración: velocidad, marcha, rpm, KERS, DRS y, por rueda, temperatura, desgaste, carga, `sliding` y superficie.
    - Teclas: F1 alterna las ayudas; F2 cicla compuesto (con neumáticos nuevos); F3 alterna la lluvia (agua 0 → 0,3 → 0,7).
    - KERS se reinicia al cruzar la meta.

- [ ] **Step 1: Test:**
  - `test_clock_caps_ticks`: `advance(1.0)` ≤ 8.
  - `test_clock_accumulates`: tres llamadas de `TICK × 0.5` suman 1 tick.
  - `test_large_frame_delta_is_substepped`: con un `CarController` aislado, un frame de 0,5 s produce como mucho 8 ticks de `TICK` y la simulación queda finita.
  - `test_test_drive_scene_runs`: instanciar `test_drive.tscn` en el árbol, sustituir `input_source` por gas a fondo y dirección 0, ejecutar 600 frames de física (`await get_tree().physics_frame`; el runner debe admitir tests con `await`), y comprobar que `distance_m` > 100 y que no hay errores en la salida.
- [ ] **Step 2:** FAIL.
- [ ] **Step 3:** Implementar. El runner de la Task 1 se amplía para hacer `await` en los métodos que devuelvan una corrutina; hay que mantener la compatibilidad con los tests síncronos.
- [ ] **Step 4:** `$RUN` completo → PASS.
- [ ] **Step 5: Verificación manual.** Abrir el editor (`Godot_v4.7.2-stable_win64.exe --path <proyecto> --editor`) o ejecutar la escena (`--path <proyecto> res://scenes/dev/test_drive.tscn`), conducir con teclado y comprobar:
  - entrar pasado en la horquilla hace que el coche siga recto o acabe en la grava;
  - pisar la chicane por el piano alto descoloca el coche;
  - con F3 en 0,7 y slicks el coche es casi inconducible;
  - un mando conectado vibra en piano y en los impactos.

  Hacer una captura de pantalla para el informe.
- [ ] **Step 6:** Commit `feat(overcut-gp): render de pista y coche 2012, cámara y escena de conducción`.

---

### Task 12: Benchmark de rendimiento con 24 coches

**Files:**
- Create: `tests/bench/bench_sim.gd` (`extends SceneTree`, se ejecuta con `--script res://tests/bench/bench_sim.gd`)

**Interfaces:**
- Consumes: `VehicleSim`, `TestTrackBuilder`.

- [ ] **Step 1:** Escribir el benchmark: 24 `CarState` repartidos por el circuito con un piloto trivial que sigue la línea central (dirección proporcional a `-lateral` y a la orientación, gas 0,8), simulando 10 s de juego (1.200 ticks). Imprimir `ms por tick (24 coches)`, la media y el p99.
- [ ] **Step 2:** Ejecutar `& $GODOT_CONSOLE --headless --path <proyecto> --script res://tests/bench/bench_sim.gd`. **Objetivo:** media ≤ 2,0 ms por tick en este PC, lo que equivale a un 24 % del presupuesto de 8,3 ms y deja margen para un móvil unas 3 veces más lento.
- [ ] **Step 3:** Si no se cumple, optimizar en este orden y volver a medir tras cada cambio: cachear `TrackGeometry.project` por coche con búsqueda local desde el último `index`; consultar la superficie por rueda solo cada 2 subpasos; usar arrays empaquetados en lugar de objetos `WheelState` en el bucle caliente; y, como último recurso, `SUBSTEPS = 2` volviendo a pasar toda la suite de dinámica. Anotar en el commit los números de antes y después.
- [ ] **Step 4:** `$RUN` completo → PASS.
- [ ] **Step 5:** Commit `perf(overcut-gp): benchmark de 24 coches y optimizaciones`.

---

## Cierre del plan

- `$RUN` completo en verde, el benchmark dentro del objetivo y la escena `test_drive` conducible con teclado, mando y táctil (el táctil se prueba en el navegador cuando el plan 8 instale las plantillas de exportación; aquí se valida con la emulación de táctil por ratón de Godot, `input_devices/pointing/emulate_touch_from_mouse=true` en la escena de pruebas).
- Informar al usuario de los números del banco de rendimiento y de qué constantes del modelo se ajustaron para entrar en los rangos de realismo.
- Las plantillas de exportación web de Godot 4.7.2 **no están instaladas**: el plan 8 las descargará, con aprobación previa del usuario porque ocupan mucho.
