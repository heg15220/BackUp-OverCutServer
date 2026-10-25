# OverCut GP — Plan 2: Versión jugable completa en 3D, Melbourne 2012

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:executing-plans (ejecución directa elegida por el usuario). Steps use checkbox (`- [ ]`) syntax.

**Goal:** Desde el botón de OverCut: menú → temporada 2012 → elegir equipo y piloto → ajustes (dificultad, duración) → GP de Australia en un Albert Park 3D real (OSM + elevación + ambiente) → clasificación Q1/Q2/Q3 → salida con semáforos → carrera con 24 coches 3D de 2012, IA, neumáticos, boxes y V8 → resultados y mundial 2012.

**Architecture:** La simulación del plan 1 se mantiene (plano XZ) más pendiente y altura. Un mundo 3D (`world3d/`) se construye en tiempo de carga a partir de datos JSON generados por un pipeline Python (`tools/data/`) desde fuentes abiertas. Un `RaceSession` coordina todos los coches (un único stepper), la IA, las reglas y el HUD. La UI es Control responsive.

**Tech Stack:** Godot 4.7.2 (GDScript, renderer Compatibility, 3D), Python 3 + numpy/scipy para el pipeline de datos y la síntesis de audio.

**Spec:** `docs/superpowers/specs/2026-10-25-overcut-gp-design.md` (secciones 5–13 y la 18, el cambio a 3D).

## Global Constraints
- Todo lo del plan 1 sigue vigente (Godot 4.7.2 GDScript, 120 Hz, SI, determinismo, sin material con derechos).
- Renderer `gl_compatibility` (único que exporta a web/móvil). Presupuesto web: carga inicial ≤ 60 MB, sombras de una DirectionalLight3D, sin GI.
- Datos generados se versionan (`data/*.json`); las descargas crudas no (los scripts las vuelven a bajar). Atribuciones en `CREDITS.md`: OpenStreetMap (ODbL), TUMFTM racetrack-database (LGPL-3.0), Copernicus DEM vía Open-Meteo, f1db (CC BY 4.0).
- Tests headless con `tools/run_tests.sh`; lo visual se verifica con capturas (`--capture`), que se enseñan al usuario.
- No se da nada por terminado sin captura real y prueba del export web.

## Review Focus
1. Coches de IA atascados (contra un muro o trompeados): deben recuperarse (marcha atrás) o retirarse, nunca bloquear la sesión. → `test_ai_recovers_from_wall` (Task 7).
2. Varios coches en el mismo punto (salida, primera curva): contacto coche-coche sin interpenetración ni NaN. → `test_car_contacts_separate` (Task 7).
3. Usuario que abandona o se retira a mitad de carrera: el resto se simula hasta el final y hay resultados. → `test_race_finishes_without_player` (Task 9).
4. Pantallas estrechas y verticales: el menú y el HUD no se salen de pantalla a 360×740. → captura en vertical (Tasks 8 y 10).
5. Carga en web: el mundo de Melbourne se construye en < 8 s en el PC y sin tirones de memoria. → medido en Task 4.

---

### Task 1: Pipeline de datos de Melbourne y de la temporada 2012
**Files:** `tools/data/fetch_sources.py`, `tools/data/build_melbourne.py`, `tools/data/build_season_2012.py`, `data/tracks/melbourne_2012.json`, `data/seasons/2012.json`, `CREDITS.md`.
**Produces:**
- `melbourne_2012.json`: `points` (m, x este / y sur, origen en `origin_latlon`), `heights` (m, por punto, suavizado), `width_left/right`, `kerb_left/right`, `kerb_high_*`, `runoff_left/right` (nombres de `Surface.Type`), `wall_left/right`, `start_index` (línea de meta), `pit_lane` (polilínea + `entry_index`/`exit_index`), `grid` (24 casillas: posición + rumbo), `drs_zones` ([{detection_s, start_s, end_s}]), `sectors` ([s1, s2]), `racing_line` (lateral por punto, curvatura mínima), `environment` (`lake` polígono, `trees` puntos, `buildings` [{footprint, height}], `parks` polígonos, `grandstands` [{polyline, depth}]), `terrain` (rejilla DEM), `laps` 58, `length_m`.
- `2012.json`: `calendar` (20 GP con `available` true solo para Melbourne), `points` [25,18,15,12,10,8,6,4,2,1], `teams` (id, nombre, colores `primary/secondary/accent`, chasis, motor, `car` paramétrico de forma), `drivers` (número, nombre, abreviatura, equipo, casco), `pace` (por equipo y por GP, delta % en clasificación respecto al mejor) y `real_results` de Melbourne (Q1/Q2/Q3 y carrera) para calibrar.
**Decisiones:** escapatorias de Albert Park por tramos de `s` (grava en T1, T3, T6, T9-10, T11-12, T13; hierba en rectas; asfalto en la salida de boxes), muros de hormigón a 3–12 m (circuito semiurbano); DRS 2012: una zona en la recta de meta, detección a la salida de T14. Línea de carrera por curvatura mínima (scipy, QP sobre el desplazamiento lateral con márgenes de 1,2 m).
- [ ] Test Python `tools/data/test_build.py`: longitud 5.250–5.350 m, 24 casillas, 20 GP, 12 equipos, 24 pilotos titulares, pole real 84.922 s, alturas finitas entre −2 y 40 m, línea de carrera dentro de la pista.
- [ ] Ejecutar → FAIL; implementar; → PASS; commit.

### Task 2: Pendiente y altura en la simulación
**Files:** `sim/track/track_data.gd` (+`heights`), `sim/track/track_geometry.gd` (`height_at(p)`, `grade_at(p, heading)`), `sim/car/vehicle_sim.gd` (gravedad a lo largo del coche), `sim/track/track_loader.gd` (JSON → `TrackData` + extras), tests.
- [ ] Tests: cuesta arriba del 5 % frena un coche costeando más que en llano (Δv razonable con g·sin); `height_at` interpola; el loader carga Melbourne con 24 casillas y las zonas DRS; DRS solo se abre dentro de zona y a <1 s en detección (regla en `RaceRules`, Task 9).
- [ ] FAIL → implementar → PASS → commit.

### Task 3: Coche 2012 en 3D (modelo paramétrico por equipo)
**Files:** `world3d/car_model_2012.gd` (genera `ArrayMesh` con `SurfaceTool`), `world3d/car_visual.gd` (Node3D: chasis, ruedas que giran y se orientan, casco, sombra), `world3d/materials/*.gdshader`.
**Medidas (reglamento técnico FIA 2012 y fichas públicas):** ancho total 1.800 mm; ala delantera 1.800 mm; ala trasera 750 mm de ancho; altura máx. 950 mm; chasis máx. 625 mm y morro ≤ 550 mm desde 1.950 mm por delante del cockpit (escalón "ornitorrinco"); neumáticos Ø660 mm, 245 mm delante y 325 mm detrás; batalla por equipo (≈3,2–3,5 m); voladizo delantero ≤ 1.200 mm y trasero ≤ 600 mm. Parámetros por equipo en `2012.json` (`nose_step`, `nose_height`, `sidepod_length`, `engine_cover_fin`, colores). McLaren sin escalón.
- [ ] Test: el mesh generado cabe en 5,2 × 1,8 × 0,95 m y tiene ruedas en las posiciones de batalla/vías; colores aplicados por equipo.
- [ ] Captura de los 12 coches en fila (escena `scenes/dev/car_gallery.tscn`) → enseñar al usuario.

### Task 4: Albert Park en 3D
**Files:** `world3d/track_world_builder.gd` (terreno DEM con la pista "planchada", cinta de asfalto con alturas, pianos, líneas, escapatorias, muros de hormigón, barreras de neumáticos, vallas de malla), `world3d/environment_builder.gd` (lago con shader de agua, árboles con `MultiMeshInstance3D` desde los puntos OSM + relleno de parques, edificios extruidos, gradas, boxes y muro de boxes, pórtico de salida con semáforo, cielo y sol), `world3d/shaders/*`.
- [ ] Test headless: el mundo se construye sin errores, nº de árboles ≥ 3.000 instancias, < 8 s.
- [ ] Capturas (recta de meta, T1-T3, lago) → enseñar.

### Task 5: Cámara cenital 3D, control del jugador y escena de carrera libre
**Files:** `world3d/overhead_camera.gd` (alta, inclinada ~65°, perspectiva, sigue al coche con anticipación; modo fijo por defecto y modo que gira), `game/race_scene.gd/.tscn` (mundo + coches + cámara + táctil + HUD mínimo).
- [ ] Captura conduciendo en Melbourne → enseñar.

### Task 6: Rendimiento real de coches y pilotos 2012
**Files:** `game/season_model.gd` (de `2012.json` a `CarSpec` por equipo y `DriverProfile` por piloto), `tests/calibration/test_melbourne_pace.gd`.
**Decisión:** el ritmo del equipo escala potencia/carga/arrastre alrededor del baseline para reproducir el delta real de clasificación; el piloto aporta ±% según su delta medio con su compañero en 2012 (clasificación y carrera).
- [ ] Test: vuelta óptima simulada (IA Leyenda, sin tráfico) del McLaren dentro de ±1,5 % de 1:24.922 y orden de equipos coherente con la Q real (Spearman ≥ 0,8).

### Task 7: IA (5 niveles) y contacto entre coches
**Files:** `ai/speed_profile.gd` (perfil de velocidad sobre la línea de carrera con la física real), `ai/ai_driver.gd` (seguimiento de línea, frenadas, adelantamiento/defensa, uso de DRS/KERS, recuperación), `sim/car/car_contacts.gd`.
- [ ] Tests: Principiante < Intermedio < … < Leyenda en tiempo por vuelta; `test_ai_recovers_from_wall`; `test_car_contacts_separate`; 22 coches completan 3 vueltas sin atascos.

### Task 8: Menú y flujo del campeonato
**Files:** `ui/main_menu.tscn/.gd` (Temporada 2012 → equipo → piloto → ajustes), `game/championship.gd` (estado del mundial, puntos 2012, guardado local), `ui/standings.tscn`.
- [ ] Tests: puntos 25-18-…; estado del mundial tras una carrera; capturas horizontal y vertical.

### Task 9: Fin de semana: clasificación, salida y carrera
**Files:** `game/race_rules.gd` (Q1/Q2/Q3 recortada y saltable, 107 %, top-10 sale con neumático de Q2, parada obligatoria en 25/50 %, DRS, KERS por vuelta, banderas básicas, penalización por salida anticipada), `game/race_session.gd` (stepper único de todos los coches, semáforos, vuelta de formación, boxes con cambio de neumáticos y tiempos, abandonos por fiabilidad 2012), `game/results.gd`.
- [ ] Tests: eliminación 24→17→10; regla de compuesto; `test_race_finishes_without_player`; carrera de 3 vueltas completa en headless.

### Task 10: HUD 2004–2017 y etiquetas
**Files:** `ui/hud/era_2004_2017/*` (torre, vuelta, relative, clima/pista, minimapa, velocidad/marcha/KERS/DRS), `world3d/driver_tag.gd` (abreviatura sobre cada coche, Label3D billboard).
- [ ] Capturas en horizontal y vertical.

### Task 11: Sonido V8 2012
**Files:** `tools/audio/synth_v8.py` (síntesis de bucles a 4k/7k/10k/13k/16k/18k rpm, carga y retención, KERS, chirrido, público), `audio/engine_audio.gd` (crossfade y pitch por rpm y gas; 3D para rivales con atenuación y Doppler).
- [ ] Test headless: los bucles cargan y el mezclador elige las dos muestras vecinas correctas.

### Task 12: Export web e integración
- [ ] `tools/export_web.sh` al OverCut local; tamaños; captura en navegador real si la extensión de Chrome está disponible; si no, el usuario lo prueba.

---

## Registro de decisiones (ejecución)

- Task 1: Ruling: escapatorias, pianos y muros derivados de la curvatura real (ningún dato abierto los recoge); pit lane por dentro (lado del lago), coherente con los edificios del paddock en OSM — coste: aproximado, revisable circuito a circuito.
- Task 1: Ruling: línea central TUM suavizada ~7 m (σ = 1,5 puntos) antes de alinear — la T15 tenía un codo de un punto (R 15 m) que hacía trompear a la IA — coste: ±0,3 m de forma.
- Task 3: Ruling: modelos 3D procedurales por código desde el reglamento FIA 2012 y parámetros por equipo (batalla, escalón, pontones, aleta) — sin modelos de terceros.
- Task 7: Ruling (física, tras depurar la IA con telemetría): base_mu 1,70→1,95 y cl_a 4,2→5,0 (≈2,5× peso a 250 km/h, como un F1 de 2012); reparto de frenada 0,56→0,66 (a 4-5 g el eje delantero lleva ~62 % de la carga); agarre trasero ×1,15 (neumático 325 mm vs 245 mm); 62 % de la transferencia lateral al eje delantero (reglaje subvirador típico) — sin esto el coche era sobrevirador al límite y en frenada — coste: recalibrar circuitos futuros con los mismos bancos.
- Task 7: Ruling: ABS y TC actúan por eje (simétricos) y respetan la fuerza lateral (círculo de fricción); ABS trasero al 60 % y TC al 90 % del agarre sobrante; ESC opcional por frenada de una rueda (solo IA por defecto; ayuda opcional para el jugador). El TC por rueda generaba un par de guiñada propio.
- Task 7: Ruling: perfil de velocidad de la IA medido con la propia física (aceleración, frenada y skidpad estacionario), no analítico — garantiza objetivos alcanzables para cualquier coche.
- Task 7: Ruling: IA Leyenda al 93 % del perfil con anticipación 0,3 s (búsqueda en rejilla: única combinación sin incidentes en 3 vueltas) — por encima del 95 % se sale en T13/T15.
- Task 6: Ruling (cambia un anti-objetivo del spec, que era decisión mía): **compensación de agarre para la IA (×1,38 en base_mu y cl_a)**. La física del jugador da un ideal de ~86,5 s (con DRS/KERS) frente a la pole real de 84,9 s, pero la IA solo extrae el ~85 % del ideal sin salirse; con la compensación, el Leyenda en el McLaren hace 86,3 s sin DRS. Las diferencias entre equipos reproducen la clasificación real (HRT +11,8 % vs +10,1 % real). Coste: los coches de la IA pasan las curvas más rápido que su física "pura"; se puede reducir a medida que mejore el piloto IA.
- Task 6: ritmo de piloto = mediana de su diferencia en clasificación con su compañero en 2012 (Hamilton −0,40 % vs Button, Alonso −0,36 % vs Massa…).
