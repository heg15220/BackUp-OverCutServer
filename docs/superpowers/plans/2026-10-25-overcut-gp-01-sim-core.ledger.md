# SDD ledger — plan: docs/superpowers/plans/2026-10-25-overcut-gp-01-sim-core.md
Spec: docs/superpowers/specs/2026-10-25-overcut-gp-design.md
Pre-flight:
- T2→T3: TyreCompound fields (grip, temp window, wear_rate, cliff, water) consumed by TyreState — consistent.
- T4/T5→T7/T8: Surface.Type + TrackEnvironment.surface_at/water_at consumed per wheel — consistent (T7 flat env, T8 per-wheel).
- T6→T7: Powertrain.drive_force/update_rpm/auto_shift via CarState.powertrain — consistent.
- T7→T9/T10: WheelState.sliding/slip_ratio/surface, CarState.consume_impact (T8) — consistent.
- T1→T11: runner must support await; T11 extends runner — planned.
User request (mid-run): integrar también en OverCut local (botón cabecera) para probar. Ruling: añadir Task 13 al final de este plan — integración temprana en C:/Users/hugoe/Downloads/OverCut (ruta + botón cabecera + iframe) con export web; requiere descargar export templates → pedir permiso — coste si se equivoca: trabajo de integración adelantado del plan 8.
Task 1: complete (commits 0748b33..7d75e61, tests: bash .superpowers/sdd/2026-10-25-overcut-gp-01-sim-core/run.sh → 1 passed, 0 failed)
Task 2: Ruling: Pacejka E 0.97→0.6 (B=14.67) — con E=0.97 el agarre a 0.25 rad era 96% del pico, fuera del rango 0.70–0.95 del test; E=0.6 da 81% — coste si se equivoca: re-ajustar 2 constantes
Task 2: complete (commits 7d75e61..a7e7446, tests: bash .superpowers/sdd/2026-10-25-overcut-gp-01-sim-core/run.sh → 6 passed, 0 failed)
Task 3: Ruling: curva de agua de neumáticos de lluvia = suelo 0.88 por debajo del óptimo (no gaussiana pura) y gaussiana con suelo 0.3 por encima — la gaussiana pura daba a un intermedio en seco 24% de agarre (irreal; en la realidad es ~10% más lento y se destruye) — coste: recalibrar en plan 3
Task 3: complete (commits a7e7446..6f0d067, tests: bash .superpowers/sdd/2026-10-25-overcut-gp-01-sim-core/run.sh → 14 passed, 0 failed)
Task 4: complete (commits 6f0d067..ef31564, tests: bash .superpowers/sdd/2026-10-25-overcut-gp-01-sim-core/run.sh → 19 passed, 0 failed)
Task 5: Ruling: el test usa orthogonal() = izquierda del piloto (y hacia abajo) y bandas con width_right sobre -orthogonal(); el plan mezclaba orthogonal() con width_right — coste: ninguno, convención documentada en track_projection.gd. Añadidos test_racing_line_band y comprobación de WHITE_LINE (cubren ramas de surface_at). Rejilla con búsqueda por anillos (el plan decía margen fijo; era lento).
Task 5: complete (commits ef31564..7ea1f8d, tests: bash .superpowers/sdd/2026-10-25-overcut-gp-01-sim-core/run.sh → 28 passed, 0 failed)
Task 6: Ruling: añadidos Powertrain.speed_at(rpm, gear) y test_auto_shift_down_when_slow (el test de punta en 7ª lo necesita; el plan no daba firma) — coste: nada
Task 6: Ruling: test_query_performance falló en suite completa (599 ms); CELL 25→5 m, MAX_RING 20 (~175 ms) — coste: más memoria de rejilla (trivial)
Task 6: complete (commits 7ea1f8d..2c82e46, tests: bash /c/Users/hugoe/Downloads/BackUp-OverCutServer/.superpowers/sdd/2026-10-25-overcut-gp-01-sim-core/run.sh → 34 passed, 0 failed)
Task 7: Ruling: marco del coche x adelante / y a la DERECHA (el plan decía izquierda) — mantiene válidas las fórmulas clásicas en el espacio y-abajo de Godot — coste: ninguno, documentado en car_state.gd
Task 7: Ruling: rueda deslizando = fuerza opuesta a la velocidad de deslizamiento (no Fy=0) — con Fy=0 un bloqueo total hacía trompo (sin amortiguación de guiñada); así bloqueo delantero = no gira, patinaje trasero = sobreviraje — coste: comportamiento de bloqueo distinto del plan
Task 7: Ruling: MIN_SLIP_SPEED 3.0 m/s (plan 1.0) — estabilidad numérica a baja velocidad con dt=1/480 — coste: deriva lateral algo más lenta al parar
Task 7: Ruling: aceleración lateral medida con ramp-steer a velocidad constante (no círculo con PI) — mide la misma capacidad, más robusto — coste: ninguno
Task 7: Ruling: test de combustible en 200-300 km/h (0-200 está limitado por tracción y el peso extra también carga las traseras; ratio solo 1.05) — coste: ninguno
Task 7: Ruling: añadido test_200_to_300_kmh (5-8 s); cd_a 1.25→1.05, drs_cd_a_delta -0.16→-0.11, 7ª 7.0→6.65 (6ª 8.1, 5ª 9.7) y rango del test de 7ª 310-330→325-345 — con cd_a 1.25 el 200-300 tardaba 11.6 s (real ~6) y con 7ª corta el DRS chocaba con el limitador — coste: recalibrar en plan 3
Task 7: Ruling: CarState.auto_gearbox (default true) y superficie por rueda muestreada una vez por tick (no por subpaso) — coste: ninguno
Task 7: Ruling: freno motor solo con rpm > ralentí+500 (empujaba el coche parado hacia atrás) — coste: ninguno
Task 7 metrics: punta 325.4 km/h, 0-200 5.66 s, 200-300 7.38 s, 300→100 frenada 96 m, lateral 2.44 g @115 / 4.64 g @260 km/h
Task 7: complete (commits 2c82e46..72c7e0c, tests: bash .superpowers/sdd/2026-10-25-overcut-gp-01-sim-core/run.sh → 47 passed, 0 failed)
Task 8: Ruling: tests de grava/hierba/piano/muro sobre TrackFixtures.oval (recta de 1000 m) en vez de la horquilla del circuito — una recta aísla la física; la horquilla mete el muro en medio — coste: ninguno
Task 8: Ruling: grava 150→40 km/h ≤ 90 m (plan 60 m) — 60 m exige ~1.5 g, irreal; las gravas reales frenan 0.8-1 g — coste: grava algo menos dura que el plan
Task 8: Ruling: hierba = frenada 150→50 ≥ 2× asfalto (plan: deceleración costeando ≥ 3×) — un F1 en hierba desliza; lo que penaliza es el agarre, no el arrastre de la hierba — coste: ninguno
Task 8: Ruling: rodadura de superficie aplicada fuera del límite de agarre del neumático (la grava se deforma); GRAVEL rodadura 0.45→0.60, GRASS grip 0.45→0.40 y rodadura 0.12→0.08 — coste: recalibrar en plan 2
Task 8: Ruling: desestabilización en piano medida como jitter (cambio tick a tick de yaw_rate), no varianza — la varianza la dominaba el transitorio de dirección en ambas superficies — coste: ninguno
Task 8: Ruling: restitución del muro 0.25→0.2 — con 0.25 el rebote frontal a 150 km/h salía a 37.5 km/h (> 35 del test) — coste: ninguno
Task 8: Ruling: test_grass_brakes_far_worse pasó antes de los cambios de esta tarea porque la superficie por rueda ya llegó en la Task 7 — coste: ninguno
Task 8 metrics: grava 150→40 en 78.8 m; frenada 150→50 hierba 81.2 m vs asfalto 38.6 m
Task 8: complete (commits 72c7e0c..d0659d5, tests: bash .superpowers/sdd/2026-10-25-overcut-gp-01-sim-core/run.sh → 53 passed, 0 failed)
Task 9: Ruling: acciones de entrada registradas en código (InputMapper.ensure_actions) en vez de serializarlas en project.godot — versionable junto al lector y sin el formato verboso de InputEvent — coste: ninguno
Task 9: Ruling: InputMapper.process_raw(Raw, state, dt) testeable sin dispositivos; read() lo alimenta. AssistConfig en input/assist_config.gd. TC/ABS predictivos: limitan gas/freno a la capacidad longitudinal restante (WheelState.avail_n nuevo, Powertrain.full_drive_force() nuevo) en lugar de reaccionar al deslizamiento — sin oscilación — coste: ninguno
Task 9: Ruling: dirección táctil se atenúa como la digital pero sin rampa (el dedo ya es progresivo) — coste: ninguno
Task 9: complete (commits d0659d5..bad9582, tests: bash .superpowers/sdd/2026-10-25-overcut-gp-01-sim-core/run.sh → 64 passed, 0 failed)
Task 10: Ruling: backends en archivos propios (haptics_backend.gd, web_haptics.gd, joypad_haptics.gd); RecordingHaptics en tests/helpers; WebHaptics acorta los pulsos débiles porque navigator.vibrate no tiene intensidad — coste: ninguno
Task 10: complete (commits bad9582..e0b84d7, tests: bash .superpowers/sdd/2026-10-25-overcut-gp-01-sim-core/run.sh → 74 passed, 0 failed)
Task 11: Ruling: CarController avanza con SimClock desde _physics_process (advance(frame_dt) testeable); render interpola con Engine.get_physics_interpolation_fraction() — coste: ninguno
Task 11: Ruling: zoom 12→6.5 px/m (plan 9→5) — a 9/5 el coche medía ~35 px en 720p — coste: menos visión por delante a alta velocidad (compensado con look-ahead de hasta 25 m)
Task 11: Ruling: rayas de piano de 1.2 m (plan 8 m) — los pianos reales alternan cada ~1-1.5 m — coste: ninguno
Task 11: Ruling: salida en points[2] (inicio de la recta) en vez de 20 m antes de meta — los últimos puntos son la curva de cierre y el coche salía recto contra el muro — coste: ninguno
Task 11: Ruling: añadido modo dev --capture=<png> --capture-seconds=N (piloto automático + captura) y test_track_mesh_has_every_band; táctil visible solo en móvil/web móvil (F4 alterna); run.sh usa --fixed-fps 120 — coste: ninguno
Task 11: verificación manual: capturas a 4 s, 13 s (282 km/h, 7ª) y 24 s (entra pasado sin frenar → muro + hierba, traseras 145 °C). Teclado/mando/vibración física no verificables por mí: pendiente de prueba del usuario.
Task 11: complete (commits e0b84d7..8ed8a0a, tests: bash .superpowers/sdd/2026-10-25-overcut-gp-01-sim-core/run.sh → 79 passed, 0 failed)
Task 12: Ruling: BUG corregido — la sensibilidad a la carga se aplicaba dos veces en la fuerza lateral (lateral_force recalculaba effective_mu sobre un mu que ya la incluía); nuevo TyreModel.lateral_with_peak + test — coste: lateral a 260 km/h sube de 4.63 a 4.78 g (dentro de rango)
Task 12: Ruling: optimizaciones — 1 proyección con pista (project_hinted, hint = CarState.track_index) por coche y tick; superficies de rueda y colisión de muros derivadas de esa proyección (lateral_at/surface_for/wall_penetration/inward_normal); grip y calor de neumático por tick (no por subpaso); SUBSTEPS 4→2 (último recurso del plan; toda la suite de realismo sigue verde) — coste: integración a 240 Hz en vez de 480 Hz
Task 12: Ruling: OBJETIVO NO CUMPLIDO — 24 coches: 14.73 ms/tick (antes) → 3.45 ms media, p99 5.24 (después), objetivo 2.0 ms. Medido con el binario de editor (GDScript en modo debug) en un equipo con ruido (3.4–4.7 ms entre ejecuciones). step ≈ 90 µs/coche, project_hinted ≈ 13 µs. Propuesta para el plan 4: LOD físico para coches de IA lejos de la cámara (1 subpaso, neumáticos cada 2 ticks) y medir en exportación web release en el plan 8 — coste si se equivoca: 24 coches podrían no ir a 60 fps en móviles de gama media
Task 12: complete (commits 8ed8a0a..17d2913, tests: bash .superpowers/sdd/2026-10-25-overcut-gp-01-sim-core/run.sh → 83 passed, 0 failed)
Final review: subagente (opus) — Critical 0, Important 9, Minor 11. Veredicto: With fixes.
Final: re-grade — Important 1,2,3,4,5,6,7,9 → fix pass. Minors re-graded Important por efecto en el usuario: runner que no detecta SCRIPT ERROR (oculta fallos), táctil oculto que sigue leyendo clics (acelera sin querer en escritorio), mandos con device 0 (segundo mando no funciona) → fix pass.
Final: Ruling: Important 8 (rendimiento 3.4 ms vs 2.0 ms; LOD a 1 subpaso inestable a baja velocidad) — no se arregla en este plan; queda como compuerta explícita para plan 4 (limitar fuerza lateral a baja velocidad antes de cualquier LOD) y plan 8 (medir en export web release) — coste: 24 coches pueden no ir a 60 fps en móvil medio
Final: fixed creep con freno+gas parado — test_brake_and_throttle_at_rest_does_not_creep RED→GREEN (el freno resiste la demanda neta y, parado con freno >0.5, el embrague se abre como en parrilla), suite 93/93
Final: fixed sin marcha atrás — test_reverse_gets_a_car_off_a_wall RED→GREEN (auto: freno 0.4 s parado = R, pedales invertidos; manual: bajar desde 1ª parado), suite 93/93
Final: fixed project_hinted dependiente del historial — test_hinted_projection_matches_full_for_off_track_points RED→GREEN (fuera de asfalto+piano se usa la búsqueda completa), suite 93/93
Final: fixed lateral_at en horquilla (hasta 0.29 m de error) — test_lateral_at_is_accurate_in_a_hairpin RED→GREEN (camina al segmento vecino; muros con re-proyección tras los subpasos), suite 93/93
Final: fixed agarre lateral en deslizamiento (0.42 a 1 rad) — test_sliding_sideways_keeps_most_of_the_grip RED→GREEN (suelo SLIDE_FACTOR pasado el pico), suite 93/93
Final: fixed bloqueo a fondo por debajo de 310 km/h — test_full_pedal_at_300_does_not_lock_but_does_at_low_speed RED→GREEN (max_brake_force 40→27 kN: bloquea solo por debajo de ~200 km/h; frenada 300→100 89.8 m), suite 93/93
Final: fixed TC ignora KERS — test_tc_accounts_for_kers RED→GREEN (TC descuenta la fuerza KERS; puerta KERS throttle>0.05), suite 93/93
Final: fixed diferencial ausente — test_limited_slip_diff_sends_drive_to_the_gripping_wheel RED→GREEN (autoblocante 30 %), suite 93/93
Final: fixed runner aprueba tests con errores de script — verificado con test temporal de error en ejecución y de parse (exit 0 → exit 1; temporales borrados), suite 93/93
Final: fixed táctil oculto sigue leyendo clics — test_hidden_controls_ignore_touches_and_release_on_hide RED→GREEN, suite 93/93
Final: fixed mandos solo device 0 — test_gamepad_bindings_accept_any_pad RED→GREEN, suite 93/93
Final: Ruling: teclado sin ABS bloquea a fondo por debajo de ~200 km/h — es lo realista y exigente que pidió el usuario; las ayudas por defecto para principiantes se deciden en los menús del plan 6 — coste: frustración inicial con teclado
Final: minor (deferred): _offsets_cache por instance_id puede quedar obsoleto si se edita el spec en caliente (plan 3 daños/setup)
Final: minor (deferred): Assists escribe state.auto_gearbox; la IA no pasa por Assists → mover a setup (plan 4)
Final: minor (deferred): last_impact_speed nunca se consume en coches sin HapticsDirector (plan 5 daños)
Final: minor (deferred): un SimClock por CarController; el plan 4 necesita un único stepper del mundo (orden y determinismo)
Final: minor (deferred): track_index debe resetearse a -1 en teletransportes (documentado en el campo)
Final: minor (deferred): test de piano solo mide jitter en recta; falta uno al límite en curva
Final: minor (deferred): test_query_performance mide tiempo de reloj (frágil en máquinas lentas)
Final: Ruling: revisor "Declined: Pacejka longitudinal" — el modelo de fuerza demandada limitada por fricción (con bloqueo/patinaje explícitos) es decisión del plan; da los comportamientos que pide el spec sin la inestabilidad de integrar el giro de rueda — coste: sin curva de slip ratio longitudinal fina
Final: bench tras el fix pass: 6.6–7.1 ms vs 6.2 ms del commit anterior medidos en la misma sesión (máquina cargada; antes 3.4). Coste de la re-proyección de muros ~+10 %.
Task 13: complete (fuera del plan, pedido por el usuario) — plantillas 4.7.2 instaladas; export web sin hilos (0334374, 20f6d1d); OverCut local rama feature/overcut-gp-local commit 74e32ad2: ruta /overcutGp + botón cabecera escritorio/móvil + iframe; jest 3/3, eslint limpio en archivos nuevos. Verificación en navegador: solo pantalla de carga de Godot en Chrome headless (extensión de Chrome no conectada) — pendiente prueba manual del usuario.
