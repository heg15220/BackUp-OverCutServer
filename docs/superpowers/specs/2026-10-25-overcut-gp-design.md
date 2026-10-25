# OverCut GP — Diseño

Fecha: 2026-10-25 · Estado: borrador para aprobación
Nombre de trabajo: **OverCut GP** (decisión mía, cambiable; sigue el patrón OverCutCareer / OverCutDraft).

Leyenda: **[Usuario]** = decidido por el usuario · **[Mía]** = decisión mía, revisable · **[Builder]** = queda a criterio de quien construya.

---

## 1. Qué es y por qué

Un juego de carreras de F1 en 2D con cámara cenital, hecho en Godot, integrado como una sección más de la plataforma OverCut. Los circuitos son recreaciones fieles de los reales; los coches, equipos, pilotos, reglamentos y sistemas de puntuación son los de cada temporada real desde 1980. El jugador ocupa el asiento de un piloto real y disputa un campeonato completo (clasificación + carrera en cada GP), con física exigente, clima dinámico, incidentes y un sistema de I+D.

Lo que lo hace especial: **la simulación**. El usuario quiere que sobre todo salgan perfectos **la física de carrera, el modelado de los monoplazas y el de los neumáticos** [Usuario]. Todo lo demás se apoya en eso.

## 2. Objetivos, no-objetivos y anti-objetivos

### Objetivos (visión completa)
- Campeonatos de cualquier temporada desde 1980 hasta la actual, con equipos, pilotos, calendarios, reglamentos y puntuación reales año a año [Usuario].
- Sprints en las temporadas que los tuvieron (2021+) [Usuario].
- Rendimiento piloto/coche lo más realista posible para IA y jugador [Usuario].
- Juego responsive y jugable de verdad en ordenador, tablet y móvil (horizontal y vertical) [Usuario].

### Objetivo de la Fase 1 (lo que se construye ahora)
**La temporada 2012 completa** [Usuario]: los 20 GP, los 12 equipos y los 24 pilotos titulares (más los sustitutos reales cuando los hubo, p. ej. D'Ambrosio por Grosjean en Monza), campeonato íntegro con su puntuación, guardado con código, I+D y monedas, HUD de la era 2004–2017, sonido V8 2.4 L de 2012. Todo con el núcleo físico al nivel final.

### No-objetivos de la Fase 1
- Otras temporadas que no sean 2012 (el modelo de datos sí debe admitirlas desde el principio).
- Otros estilos de HUD que no sean el de 2004–2017 (la arquitectura sí debe admitir uno por época).
- Multijugador.
- Cuentas de usuario: no hace falta iniciar sesión [Usuario].

### Anti-objetivos (aunque funcione, sería un fracaso)
- **Conducción arcade.** Frenar tarde, pisar piano o salirse tiene que penalizar [Usuario].
- **IA tramposa.** La IA usa la misma física que el jugador, sin rubber-banding ni agarre extra; su nivel solo cambia cuánto se acerca al límite y sus decisiones [Mía, deriva de lo que pide el usuario].
- **Datos inventados donde existen datos reales** (calendario, pilotos, colores, reglamento).
- **Un modo vertical de segunda** en móvil: tiene que sentirse profesional [Usuario].
- **Copiar material protegido:** nada de logos, tipografías oficiales de F1 ni grabaciones de motores reales. Los HUD son inspirados, y el sonido es sintetizado [Mía, el usuario lo ha aceptado].

## 3. Restricciones

- **Motor:** Godot 4.7.2 **estándar (GDScript)**, no la versión .NET: en Godot 4 los proyectos en C# no se pueden exportar a web, y el juego tiene que ir dentro de la web [Mía, aceptada]. Ejecutable: `C:\Users\hugoe\AppData\Local\Programs\Godot\Godot_v4.7.2-stable_win64.exe`.
- **Plataforma:** exportación web (HTML5/WASM) incrustada en el frontend React de OverCut.
  - [Builder] Elegir entre la exportación sin hilos (no necesita cabeceras COOP/COEP y funciona en cualquier hosting) y la exportación con hilos (necesita esas cabeceras en nginx y aislar el iframe). Recomiendo la exportación sin hilos salvo que la física la descarte por rendimiento.
- **Rendimiento:** 60 fps en un móvil Android de gama media con 24 coches en pista. La física corre a paso fijo (por ejemplo, 120 Hz) e independiente del renderizado.
- **Tamaño de carga:** la primera carga debe ser razonable en móvil. Los recursos de cada circuito se cargan bajo demanda.
- **Vibración:** en móvil con `navigator.vibrate`, que funciona en Android. En iOS Safari no hay API de vibración para webs, así que allí no habrá vibración (limitación de Apple, aceptada). En ordenador, vibración del mando con la Gamepad API (`vibrationActuator`).
- **Verificación en OverCut:** el usuario no quiere que se lancen builds completas de frontend (`react-scripts build`) ni de backend (`mvn compile`) para verificar. El frontend se verifica con eslint y jest; el backend, revisándolo contra los patrones existentes. La exportación y los tests de Godot sí se ejecutan.

## 4. Integración en OverCut

- **Dos bases de código** [Usuario]:
  - **Plataforma desplegada:** `C:\Users\hugoe\Downloads\BackUp-OverCutServer\overcutf1\OvercutDespliegue\overcut`. Una tarjeta nueva en `frontend/src/modules/app/components/StartHome.js`, junto a OverCutCareer y OverCutDraft, y una ruta nueva en `Body.js` (propuesta: `/overcutGp`, envuelta en `withAdVignettes(..., "games", "bottom")` como las demás). Necesita una imagen para la tarjeta (`aboutOvercut/OverCutGP.png`), que la crea el builder.
  - **OverCut local:** `C:\Users\hugoe\Downloads\OverCut\overcut`. Acceso desde **un botón en la cabecera**, para probarlo en local [Usuario].
- **Sin login:** la ruta no va detrás de `loggedIn` [Usuario].
- **Incrustación** [Mía]: la exportación web de Godot vive en `frontend/public/games/overcut-gp/` y una página React la carga en un iframe a pantalla completa, con un botón para salir y volver a OverCut.
- **Puente Godot ↔ React:** mediante `postMessage` o `JavaScriptBridge`. Sirve para el guardado (código, carga y guardado), salir y el idioma ES/EN, siguiendo el i18n que ya usa OverCut.
- **Proyecto Godot:** vive en el repositorio, en `overcut/godot/overcut-gp/` [Mía]. Hay que versionar el código y los recursos fuente, y decidir si la exportación compilada entra en git o se genera con un script [Builder].

### Guardado
Igual que OverCutCareer [Usuario]:
- Código de exportación de 12 caracteres, con el formato y la normalización que usan `normalizeSaveCode` y `formatSaveCode` en `CareerMode.js`.
- El código se recuerda en `localStorage`.
- El estado completo del campeonato se guarda en el servidor con un endpoint nuevo `POST /api/overcutGp/saves` y `GET /api/overcutGp/saves/{code}`. Se copian `CareerModeSaveController`, `CareerModeSaveService` y la entidad `CareerModeSave` en versiones propias.
- El endpoint debe ser público en `SecurityConfig`, igual que el de careerMode.
- Hay que guardar el estado entre GP y también a mitad de fin de semana (después de la clasificación).
- [Builder] Formato del estado: un JSON versionado (`schemaVersion`) para poder migrar guardados cuando se añadan temporadas.

## 5. Controles y diseño responsive

- **Móvil en horizontal (forma principal)** [Usuario]: botones táctiles de acelerar, frenar y girar.
  - Mi propuesta es que acelerador y freno sean **progresivos** según cuánto se desliza el dedo dentro del botón, porque una conducción exigente necesita dosificar.
  - El giro también es progresivo, con dos zonas o un deslizador.
  - Los botones son grandes y semitransparentes. Su posición y su tamaño se pueden ajustar en el menú de opciones.
- **Móvil en vertical** [Usuario]: pista en la parte superior con la cámara un poco más alejada, una franja inferior con los mismos controles y los paneles del HUD plegados en pestañas compactas. Tiene que verse profesional, no como un modo de emergencia.
- **Tablet:** igual que el móvil, aprovechando el espacio extra para mostrar más paneles abiertos.
- **Ordenador:** teclado (flechas o WASD, con espacio y atajos para KERS y DRS) y mando con gatillos analógicos.
- **Ayudas opcionales** [Mía]: control de tracción, ABS, línea de frenada ideal y cambio automático. Todas se pueden desactivar. Correr sin ayudas da un bonus de monedas.
- **Controles de carrera 2012:** KERS (unos 6,7 s y 60 kW por vuelta) y DRS (solo en sus zonas, a menos de 1 s del coche de delante en el punto de detección; en clasificación y entrenamientos se puede usar libremente en esas zonas, como en 2012). Llamada a boxes con elección de compuesto.
- **Vibración** [Usuario]: al pisar piano (patrón rítmico según la velocidad), al bloquear ruedas, al patinar, al salirse a la hierba o a la grava y al chocar (pulso fuerte). Mismo lenguaje en móvil y en mando. Se puede desactivar.

## 6. Núcleo físico (prioridad máxima)

La física corre en 2D, con el modelo más fiel posible a la dinámica real [Usuario]. Componentes obligatorios:

- **Modelo de vehículo:** cuerpo rígido 2D con modelo de bicicleta o de cuatro ruedas.
  - Transferencia de carga longitudinal y lateral.
  - Carga aerodinámica que crece con v² y se reparte entre los ejes (balance aerodinámico).
  - Resistencia al aire, que crece con v².
  - Potencia según una curva de par a lo largo de las rpm, con caja de cambios de 7 velocidades.
  - Frenada con reparto y bloqueo de ruedas.
  - Diferencial.
- **Modelo de neumático:** curvas de agarre tipo Pacejka (fórmula mágica simplificada) para el agarre lateral y el longitudinal, combinados mediante el círculo o la elipse de fricción. Si frenas mientras giras, pierdes giro.
  - **Temperatura** de cada rueda: ventana óptima según el compuesto, calentamiento por deslizamiento y carga, enfriamiento con el aire y la pista.
  - **Desgaste:** según el deslizamiento, la carga y la temperatura, y con una caída de rendimiento al final de su vida útil (el "cliff" de los Pirelli de 2012).
  - **Compuestos 2012:** superblando, blando, medio y duro, además de intermedio y lluvia extrema. Pirelli llevaba dos compuestos de seco por GP según el circuito, y se usa la asignación real de 2012.
  - Un neumático frío o gastado agarra menos y eso se nota en el tiempo por vuelta, tanto del jugador como de la IA [Usuario].
- **Superficies:** cada punto del circuito tiene su tipo de superficie: asfalto, goma acumulada en la trazada, piano (bajo y alto, salchichas si existen), línea blanca (resbala en mojado), hierba, grava, asfalto de escape, muro o barrera y pit lane. Cada superficie tiene su agarre, su resistencia a la rodadura y sus "golpes". El piano desestabiliza; la grava frena y atrapa [Usuario].
- **Estado de la pista:** se engoma a lo largo del fin de semana. Con lluvia hay película de agua por zonas, con charcos en los puntos bajos, y la trazada se seca antes. Se usan intermedios o lluvia extrema según la profundidad del agua.
- **Rebufo y aire sucio:** detrás de otro coche hay menos resistencia en recta y menos carga en curva, lo que hace difícil seguirlo en curvas rápidas.
- **Daños:** alerón delantero (pierde carga y desequilibra el coche), pinchazos, suspensión y abandono por golpe fuerte.
- **Fiabilidad:** probabilidad de avería por componente (motor, caja, hidráulica, KERS, frenos). Se calibra con los abandonos mecánicos reales de 2012 de cada equipo y la modifica el I+D de fiabilidad.
- **Combustible:** salida sin repostaje (2012). El peso del combustible baja vuelta a vuelta y el coche va ganando ritmo. En las carreras recortadas se escala la carga [Builder].
- **Daño por exceso de límites:** recortar y ganar ventaja supone avisos y luego penalización, como en la realidad.

### Calibración del coche y del piloto (realismo del rendimiento)
- **Coche:** cada coche de 2012 tiene sus parámetros físicos (potencia, peso mínimo de 640 kg con piloto, carga y resistencia, eficiencia y fiabilidad). El ritmo relativo entre equipos se ajusta con datos reales de 2012: diferencias en clasificación por GP, ritmo de carrera y puntos de constructores, de modo que en cada circuito la diferencia entre coches se parezca a la real.
- **Evolución real durante la temporada** [Mía, aceptada]: los rivales mejoran o empeoran como en la realidad (por ejemplo, el repunte de Red Bull a final de 2012 o el bajón de Ferrari en clasificación). Se modela como una curva por equipo y GP.
- **Piloto:** sus atributos (ritmo a una vuelta, ritmo de carrera, consistencia, gestión de neumáticos, lluvia, adelantamiento, defensa, salidas y nivel de errores) salen de los datos de esa temporada, comparándolo sobre todo con su compañero de equipo, que es el único dato que no depende del coche. **No se usan notas de toda la carrera**: así se evita el error que ya se encontró en OverCut Trayectoria.
- **Fuente de datos:** las cachés de f1db que ya tiene OverCut (`src/main/resources/scripts/`) y los tiempos por vuelta públicos de 2012 (Ergast/f1db tienen vueltas y paradas desde 1996).
- **Criterio de aceptación:** con la IA en nivel Leyenda, los tiempos de la pole simulada en cada circuito deben quedar dentro de ±1,5 % de la pole real de 2012 en seco, y el orden medio de la parrilla debe parecerse al real (se mide con un banco de simulaciones de Monte Carlo).

## 7. IA

Cinco niveles: **Principiante, Intermedio, Profesional, Clase mundial y Leyenda** [Usuario]. Cada nivel superior mejora el ritmo, la velocidad, el rendimiento, los adelantamientos, las defensas y la estrategia [Usuario].

- **Misma física que el jugador.** El nivel regula cuánto aprovecha el límite de agarre, la precisión del punto de frenada y de la trazada, la frecuencia y gravedad de los errores, la agresividad y el criterio en los ataques y las defensas, el uso de DRS y KERS y la calidad de las decisiones de estrategia (cuándo parar y qué compuesto montar).
- **Dentro de cada nivel,** la diferencia entre pilotos la marcan sus atributos (sección 6). Un Vettel en Principiante sigue siendo más rápido que un Karthikeyan en Principiante.
- **Conducción de la IA:** sigue una trazada ideal precalculada por circuito con perfil de velocidades. Cada piloto se desvía de ella para adelantar, defenderse, ceder ante banderas azules o evitar un accidente.
- **Estrategia:** respeta las reglas (sección 8), reacciona al desgaste, a la lluvia, al coche de seguridad y a lo que hacen los rivales.

## 8. Fin de semana y reglas (2012)

Todo fiel al reglamento de cada año [Usuario]. En 2012:

- **Clasificación siempre antes de cada carrera** [Usuario]: Q1/Q2/Q3 con eliminación (24 → 17 → 10), regla del 107 %, y los 10 primeros salen con los neumáticos con los que marcaron su tiempo en Q2.
  - **Duración recortada** [Usuario]: unos 6, 5 y 4 minutos de tiempo de juego para Q1, Q2 y Q3, con el reloj de sesión acelerado de forma proporcional a los 20, 15 y 10 minutos reales. La pista mejora a lo largo de la sesión.
  - **Saltar al final de la sesión** [Usuario]: cuando el jugador ya tiene su vuelta, puede saltar al final. La IA completa la sesión en simulación con el mismo modelo.
  - **Simular sin conducir** [Mía, el usuario debe confirmarlo]: el jugador puede simular una sesión de clasificación o una carrera entera sin conducirla, y su piloto rinde como la IA en el nivel Profesional. Si abandona en carrera, el resto también se simula.
  - **Entrenamientos libres:** no hay en la Fase 1 [Mía].
- **Dificultad de la IA** [Mía]: se elige al empezar el campeonato y se puede cambiar entre un GP y otro.
- **Redondeo de la distancia:** las distancias del 25 % y del 50 % se redondean hacia arriba en vueltas enteras (por ejemplo, el 25 % de 58 vueltas son 15) [Mía].
- **Duraciones de carrera** [Usuario]: 3 vueltas, 5 vueltas, el 25 % de la distancia real o el 50 % de la distancia real.
- **Parada obligatoria** [Usuario]: en las carreras del 25 % y del 50 % es obligatorio entrar en boxes y cambiar de compuesto.
  - Si sales con un compuesto, en esa parada obligatoria no puedes volver a montar el mismo. Por ejemplo, si sales con blandos no puedes montar blandos otra vez en esa parada.
  - Una vez cumplida, en paradas posteriores sí puedes volver a montarlo.
  - En carrera mojada (intermedios o lluvia) no aplica, igual que en el reglamento real.
- **En las carreras de 3 y 5 vueltas no hay parada obligatoria** [Usuario].
- **Procedimiento de salida real:** vuelta de formación, coches en su casilla, cinco semáforos rojos y apagado. Se detecta la salida anticipada y se penaliza con drive-through [Usuario].
- **Incidentes** [Usuario]: accidentes, colisiones y abandonos por fiabilidad. Pueden provocar banderas amarillas, coche de seguridad (cuando hay coches o restos en pista; en 2012 no existía el VSC), bandera roja (accidente grave o lluvia extrema) y salida tras coche de seguridad o reanudación.
- **Banderas:** azul, amarilla y doble amarilla, y la blanca y negra por límites de pista.
- **Penalizaciones:** drive-through, stop-and-go, segundos añadidos y puestos en parrilla en la siguiente carrera.
- **Clima** [Usuario]: seco, lluvia y condiciones mixtas. El tiempo puede cambiar durante la sesión, de seco a lluvia y al revés, con más caos en las transiciones. La probabilidad de lluvia de cada GP sale de su climatología real (Malasia, Brasil, Spa…).
- **Puntos 2012:** 25-18-15-12-10-8-6-4-2-1 en carrera. No hay punto por vuelta rápida (llegó en 2019). Hay campeonato de pilotos y de constructores.

## 9. I+D y monedas

- **Monedas:** se ganan con los resultados de cada fin de semana (posición en clasificación y en carrera, adelantamientos, ganar a tu compañero, correr sin ayudas, objetivo del equipo) [Usuario]. Los valores concretos los decide el builder.
- **Mejoras** [Usuario]: **fiabilidad, motor, chasis, aerodinámica y suspensión**. Cada una se traduce en parámetros físicos concretos:
  - Motor: potencia.
  - Aerodinámica: más carga o más eficiencia.
  - Chasis: peso, rigidez y reparto de pesos.
  - Suspensión: tracción, comportamiento en pianos y desgaste de neumáticos.
  - Fiabilidad: menos averías.
  - Cada mejora tiene su coste y su tiempo de llegada (por ejemplo, 1 o 2 GP).
- **Equilibrio** [Usuario]: con un equipo de cola (HRT, Marussia) **pelear por el título debe ser muy difícil, pero con una remota posibilidad**. Mi propuesta:
  - Rendimientos decrecientes y un tope por temporada.
  - Los rivales también evolucionan (sección 6).
  - Al final de la temporada, un coche de cola bien desarrollado puede llegar a la zona media-alta, y solo con un piloto excelente, carreras caóticas y fiabilidad a favor puede pelear por el título.

## 10. HUD (era 2004–2017 para 2012)

Un estilo de HUD por época, inspirado en la tele de cada era [Usuario]. Los cortes y estilos que se aprobaron con las maquetas son los siguientes:
- 1980–1993: teletipo blanco sobre cajas azules y negras, apellidos completos y pocos datos.
- 1994–2003: cajas grises y azuladas con degradado y bisel, inicial y apellido, información de repostaje.
- **2004–2017: torre negra con cabecera roja, abreviaturas de tres letras, sectores morado/verde/amarillo, DRS (2011+) y VSC (2015+).** ← Fase 1
- 2018–2026: torre translúcida, barras de color de equipo e iconos de compuesto.

Contenido obligatorio en todas las épocas [Usuario]:
- **Abreviatura de tres letras del apellido sobre cada coche** (en las épocas en que la tele no las usaba, se usa igualmente una abreviatura con el estilo de la época).
- **Torre de posiciones:** posición, color del equipo, abreviatura, diferencia o intervalo, compuesto y vueltas del neumático, y estados (en boxes, abandonado, penalización).
- **Vueltas:** vuelta actual sobre el total, y estado de bandera, coche de seguridad o bandera roja.
- **Relative:** los coches de delante y de detrás con su diferencia en tiempo real.
- **Panel de clima y pista:** cielo, temperatura del aire y de la pista, probabilidad de lluvia y cuándo, nivel de agarre o de agua en pista, y estado de tus neumáticos (temperatura y desgaste por rueda).
- **Minimapa** del circuito con la posición de todos los pilotos.
- **Datos propios:** velocidad, marcha, rpm, KERS restante, DRS disponible o activo, delta respecto a tu mejor vuelta y sectores.

## 11. Mundo visual

- **Mundo realista en todas las épocas** (referencia: F1 Manager, Motorsport Manager) [Usuario]:
  - Asfalto con textura, goma acumulada en la trazada y marcas de frenada.
  - Hierba, grava, pianos con los colores reales de cada circuito, muros, barreras de neumáticos, gradas, pit lane y boxes, y la línea de salida con sus casillas.
  - Sombras, lluvia con salpicaduras y reflejos, y la trazada que se va secando.
  - Generación de texturas en Godot (shaders o texturas procedurales) [Usuario].
- **Coches desde arriba con la silueta de su época** [Usuario], sacada de las fichas técnicas más detalladas que haya. Para 2012:
  - Morros escalonados (el "ornitorrinco") en casi todos, con la excepción de McLaren.
  - Alerones de la normativa 2009–2013.
  - Neumáticos traseros anchos.
  - Las proporciones de cada chasis concreto (RB8, MP4-27, F2012, W03, E20, etc.) cuando se puedan distinguir desde arriba.
- **Solo los colores del equipo en esa temporada**, sin patrocinadores ni detalles [Usuario]. En 2012:
  - Red Bull: azul marino con rojo y amarillo.
  - McLaren: plata y rojo.
  - Ferrari: rojo.
  - Mercedes: plata.
  - Lotus: negro y dorado.
  - Force India: blanco, naranja y verde.
  - Sauber: blanco y negro.
  - Toro Rosso: azul y plata.
  - Williams: azul oscuro y blanco.
  - Caterham: verde y amarillo.
  - HRT: blanco y rojo.
  - Marussia: negro y rojo.
  - Los tonos exactos los investiga el builder.
- **Cámara cenital** que sigue a tu coche, con zoom ajustable y una cámara más alejada en vertical. En la parrilla, en el coche de seguridad y en las repeticiones cortas se puede mirar a otros coches [Builder].

## 12. Circuitos (Fase 1: los 20 de 2012)

Melbourne, Sepang, Shanghái, Sakhir, Barcelona, Mónaco, Montreal, Valencia (circuito urbano), Silverstone, Hockenheim, Hungaroring, Spa, Monza, Marina Bay, Suzuka, Yeongam, Buddh, Yas Marina, Austin (COTA, debut en 2012) e Interlagos.

- **Trazado fiel a la configuración de 2012** [Usuario]: línea central y ancho reales, curvas, pianos, escapatorias (grava, asfalto o hierba), muros, pit lane con su entrada y salida, casillas de salida, zonas de DRS y puntos de detección de 2012, líneas de sector y la meta.
- **Fuentes** [Mía]: datos públicos de trazados (por ejemplo, TUMFTM racetrack-database, con línea central y anchos de muchos circuitos de F1, licencia LGPL; hay que respetarla), OpenStreetMap (licencia ODbL, hay que atribuirla), imágenes de satélite como referencia visual y planos oficiales de la FIA y de los circuitos de 2012.
  - Valencia, Yeongam y Buddh ya no están en el calendario actual, así que hay que reconstruirlos a partir de OSM y planos.
- **Formato:** cada circuito es un recurso de datos (línea central, anchos, superficies, trazada ideal, zonas, metadatos y climatología) más una escena con su decoración. Un importador o herramienta en el editor genera la malla y las texturas de pista a partir de los datos [Builder].
- **Escala real en metros**, de modo que los tiempos por vuelta resultantes sean los reales (por ejemplo, unos 1:24–1:26 en Melbourne).

## 13. Sonido

- Sonido de motor **sintetizado y fiel al reglamento de cada época** [Usuario, con la limitación aceptada de no usar grabaciones]: síntesis por capas (orden de encendido, armónicos según número de cilindros y rpm, admisión y escape, carga del motor), además de efectos de cambio, corte de inyección y rebotes en el limitador.
- **2012:** V8 de 2,4 L con limitador a 18.000 rpm, el silbido del KERS y la transmisión.
- **Ambiente:** neumáticos al patinar, frenadas, piano, grava, impactos, lluvia, público y comunicaciones de radio mediante texto en pantalla [Builder].
- **Efecto Doppler y atenuación** para los coches de alrededor.

## 14. Arquitectura propuesta [Mía, el detalle queda al builder]

- **Simulación separada del renderizado:** física a paso fijo y determinista dentro de lo razonable, para poder probarla en modo headless, calibrar con Monte Carlo y simular la parte de la carrera que no se ve si el jugador abandona.
- **Datos en recursos:** `Season` (equipos, pilotos, coches, calendario, reglamento y puntos) → `Regulations` (formato de clasificación, puntos, DRS, KERS, VSC, repostaje y compuestos) → `Car` (parámetros físicos) → `Driver` (atributos) → `Circuit`. Todo pensado para que añadir 1980–2026 en fases posteriores sea solo cuestión de añadir datos y estilos.
- **Módulos:** `sim/` (vehículo, neumático, superficie, clima, carrera, reglas e incidentes), `ai/`, `data/`, `track/` (importador y render de pista), `ui/hud/<era>/`, `ui/menus/`, `audio/`, `platform/` (puente web, vibración y guardado).
- **Herramientas de calibración:** escenas o scripts headless que simulan clasificaciones y carreras completas de 2012 y comparan con los datos reales (sección 6).

## 15. Fases

1. **Fase 1 (ahora): la temporada 2012 completa**, como se describe en este documento.
2. Todas las temporadas de 1980 a 2026: datos, siluetas, colores, reglamentos, puntuaciones (incluidos los resultados descartados en la puntuación de los 80), formatos de clasificación de cada época, repostaje entre 1994 y 2009 y sprints desde 2021.
3. Todos los circuitos y sus variantes por año de 1980 a 2026.
4. HUD de las demás épocas, sonido de cada época (turbo de los 80, V10, V12, V8 y V6 híbrido) y pulido final en móvil, tablet y mando.

## 16. Verificación

- Tests unitarios y headless en Godot para el neumático, el vehículo, las reglas (parada obligatoria, Q1/Q2/Q3, 107 %, puntos) y el guardado y carga [Builder: elegir GUT o un runner propio].
- Banco de calibración con los criterios de la sección 6.
- Pruebas manuales en el navegador de escritorio y en móvil (horizontal y vertical) dentro de OverCut local.
- Frontend: eslint y jest. Backend: revisión contra los patrones existentes. Sin builds completas (sección 3).

## 17. Queda a criterio del builder
- La exportación web con o sin hilos.
- El runner de tests.
- La herramienta para importar circuitos.
- El formato exacto de los datos.
- Los valores numéricos de economía e I+D.
- El escalado del combustible en carreras cortas.
- Las cámaras secundarias.
- Las radios y el ambiente.
- Los tonos exactos de color de cada equipo (investigación).
- Si la exportación compilada se versiona en git.
