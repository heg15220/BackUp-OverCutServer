# Clasificación con garaje, tandas y rivales en pista: diseño

Fecha: 2026-10-28 · Estado: pendiente de aprobación

## Por qué

Hoy la clasificación (Q1/Q2/Q3) es el jugador solo contra el reloj. Sale ya rodando desde la
salida del pit lane y los tiempos de los rivales salen de una estimación (`Qualifying.simulate`),
que se va revelando en la tabla. El usuario quiere que se parezca a una clasificación de verdad,
como en la tele: decidir cuándo sale del garaje, gestionar el tiempo del crono y encontrarse a
los demás en pista.

Hoy además se nota el fallo: el coche aparece a 80 km/h, y si el jugador no reacciona se mete
en la grava de la curva 1 antes de saber qué pasa.

## Qué pidió el usuario (sus decisiones)

- El jugador empieza **dentro de su garaje** y sale pulsando un botón.
- Recorre el pit lane, hace la **vuelta de salida**, la **vuelta lanzada** y la **vuelta de
  entrada** al pit lane, y puede repetir **mientras quede tiempo en el crono**.
- Puede **encadenar varias vueltas lanzadas** seguidas, como en la realidad, y entra a boxes
  solo cuando quiere.
- **Los rivales también ruedan de verdad en pista** durante la clasificación, y se ven en el
  mapa del circuito.

## Objetivos

1. Ciclo de tanda del jugador: garaje → pit lane → vuelta de salida → una o varias lanzadas →
   vuelta de entrada → garaje. Se repite mientras el crono lo permita.
2. Los 23 rivales hacen sus propias tandas: salen del garaje en momentos distintos, hacen vuelta
   de salida, lanzadas y entrada. Están en pista con el jugador, así que hay tráfico (un rival
   en vuelta lenta cuando tú vas en lanzada, y al revés).
3. Los tiempos de la tabla salen de las vueltas que se dan de verdad en pista, no de una
   revelación aleatoria.
4. Las eliminaciones Q1 (24→17), Q2 (17→10), Q3 y la regla del 107 % siguen igual.
5. Mapa: puntos para todos los coches en pista; los que están en el garaje no se muestran.

## Lo que NO entra (no-objetivos)

- Conducir el pit lane a mano: va en automático con limitador, igual que las paradas en carrera.
- Juegos de neumáticos limitados, carga de combustible, banderas rojas, radio del ingeniero.
- Sonido (es otro proyecto, después de este).
- Cambios en la carrera, salvo reutilizar piezas.

## Lo que haría que fracase aunque funcione (anti-objetivos)

- Un orden de clasificación inverosímil: HRT en la pole, o Red Bull/McLaren fuera en Q1 sin
  motivo. El orden medio tiene que seguir calibrado como hoy (`AI_EFFICIENCY`, `QUALI_TRIM`,
  `EVOLUTION`).
- Que esperar en el garaje sea aburrido o que no se entienda cuánto tiempo queda.
- Que el juego en la web deje de ir fluido. Referencia: ahora mismo la carrera con 24 coches va
  a ~44 fps en Edge headless con la Vega 8. Tampoco puede volver a tardar decenas de segundos
  en cargar.
- Que el jugador quede atrapado sin poder hacer nada: siempre hay salida (botón, pausa o
  simular resto).

## Restricciones

- Godot 4.7.2, exportación web sin threads y con la plantilla propia. Todo se construye por
  código, en el estilo del proyecto (`RaceWeekend`, `QualiSession`, `RaceSession`).
- Simulación a 120 Hz con `SimClock` (máx. 8 ticks por frame).
- Tests headless con `tools/run_tests.sh`; los 147 actuales siguen pasando.
- Datos del pit lane en `melbourne_2012.json`: `pit_lane.points`, `entry_index` 959,
  `exit_index` 51 y límite de 100 km/h. Hay edificio de boxes en 3D (`_pit_building`).

## Cómo se comporta (decisiones del usuario y mías)

### Jugador
- **Inicio de cada sesión:** coche parado en su box, cámara sobre él. Botón grande
  "Salir a pista" (y tecla/mando equivalente). El crono de la sesión ya corre.
- **Pit lane de salida:** automático a 100 km/h (*mi decisión*: como las paradas en carrera).
  Al llegar a `pit_exit_index` el jugador toma el control a la velocidad del limitador.
- **Vuelta de salida:** no cuenta. La HUD indica "Vuelta de salida".
- **Vuelta lanzada:** empieza al cruzar la meta. Si pisas fuera de los límites se anula
  (ya existe `check_limits`). Al cruzar la meta otra vez, cuenta el tiempo y empieza otra
  lanzada automáticamente (encadenar).
- **Entrar a boxes:** el jugador lo pide con el botón BOXES o la tecla P, como en carrera.
  Esa vuelta pasa a ser vuelta de entrada y no cuenta. Al pasar por `pit_entry_index`, el coche
  recorre el pit lane solo y se para en su box.
- **Fin del crono:** una lanzada empezada antes de llegar a cero se puede terminar (como hoy).
  Si el crono llega a cero en el garaje, en el pit lane o en la vuelta de salida, la sesión
  termina para el jugador.
- **En el garaje:** se puede volver a salir. *Mi decisión:* un botón "Esperar ×10" acelera el
  tiempo mientras estás parado en el box, para no esperar en tiempo real. "Simular resto de la
  sesión" sigue disponible.
- **Neumáticos:** *mi decisión*: juego nuevo de blandos en cada salida del garaje (sin gestión
  de juegos, que es no-objetivo).

### Rivales
- Cada rival tiene un **plan de tandas** por sesión, generado con la semilla: cuántas salidas
  (1–3), en qué momento del crono sale cada una y cuántas lanzadas hace (1–2). *Mi decisión:*
  los buenos apuran al final y los equipos pequeños salen antes, como en 2012. Los eliminados no
  salen en la sesión siguiente.
- **Pilotaje:** reutilizando lo de la carrera. Los coches cerca del jugador usan física completa
  con `AiDriver`, para que haya tráfico real; los lejanos avanzan de forma simplificada sobre su
  perfil de velocidad. La vuelta de salida y la de entrada van a ritmo reducido.
- **Tiempo de vuelta:** el tiempo real de la vuelta en pista. Para conservar el orden calibrado,
  el modo simplificado da de media el mismo tiempo que `Qualifying.estimated_lap` (más
  `QUALI_TRIM`, `EVOLUTION` y el ruido `LAP_NOISE` que ya existen). Un test lo comprueba con
  tolerancia.
- **Box por equipo:** *mi decisión*: cada equipo tiene su box en un punto distinto del pit
  lane, en el orden del campeonato 2012. El jugador usa el de su equipo.

### Tabla de tiempos y mapa
- La tabla muestra el mejor tiempo hecho por cada coche en la sesión, y un indicador de quién
  está en pista o en el garaje.
- `final_result()` usa los tiempos dados. *Mi decisión:* si al pulsar "Simular resto" quedan
  tandas por hacer, se rellenan con la estimación actual.
- Mapa: solo coches en pista; el jugador, en amarillo, como ahora.

## Rendimiento

- La carga no puede añadir mediciones de física: los perfiles de velocidad ya están
  precalculados (`data/speed_envelopes.json`) y la carrera los reutiliza.
- Con varios coches en pista a la vez, el reparto entre física completa y modo simplificado
  limita el coste, igual que en carrera.

## Lo que queda para quien lo construya

- Cómo se reparte el código entre `QualiSession` y `RaceSession` (separar el reparto por
  distancia a una pieza común es lo natural).
- Los textos exactos de la HUD, los botones y la tecla para "Salir a pista".
- La forma concreta de generar los planes de tandas, siempre que cumpla lo de arriba y sea
  determinista con la semilla.
- La posición exacta de cada box en el pit lane.
