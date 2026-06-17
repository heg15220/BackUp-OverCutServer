package overcut.model.services;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.transaction.Transactional;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import overcut.model.entities.*;
import overcut.model.services.exceptions.CooldownException;
import overcut.rest.dtos.BingoSelectRequestDto;
import overcut.rest.dtos.BingoSelectResponseDto;

import java.net.URI;
import java.net.http.*;
import java.time.Duration;
import java.time.LocalDateTime;

@Service
@Transactional
public class BingoGameServiceImpl implements BingoGameService {

    private static final Logger log = LoggerFactory.getLogger(BingoGameServiceImpl.class);

    @Autowired private BingoGameDao gameDao;
    @Autowired private BingoCellDao cellDao;              // ✅ leer celda + validPilotIds
    @Autowired private BingoSelectionDao selectionDao;
    @Autowired private CooldownService cooldownService;

    // ✅ Reutilizable (menos basura + menos coste por request)
    private static final ObjectMapper mapper = new ObjectMapper();

    // ✅ HttpClient singleton con connectTimeout
    private static final HttpClient HTTP = HttpClient.newBuilder()
            .connectTimeout(Duration.ofSeconds(2))
            .build();

    @Value("${fastapi.base-url:http://fastapi:8000}")
    private String fastapiBaseUrl;

    // ✅ Timeouts configurables (por si quieres afinar en prod)
    @Value("${fastapi.bingo.connect-timeout-ms:2000}")
    private long fastapiConnectTimeoutMs; // (informativo; el connectTimeout del client es fijo arriba)

    @Value("${fastapi.bingo.request-timeout-ms:3000}")
    private long fastapiRequestTimeoutMs;

    @Override
    public BingoGame startGame(String lang, Long userId) {
        long t0 = System.currentTimeMillis();

        try {
            // 1) Cooldown
            if (!cooldownService.canPlay("Bingo", userId)) {
                long wait = cooldownService.secondsUntilNextPlay("Bingo", userId);
                throw new CooldownException("WAIT", wait);
            }
            long t1 = System.currentTimeMillis();

            // 2) FastAPI call (reutilizable + timeout)
            String safeLang = (lang == null || lang.isBlank()) ? "es" : lang.trim();
            URI uri = URI.create(fastapiBaseUrl + "/generate-bingo?lang=" + safeLang);

            HttpRequest request = HttpRequest.newBuilder()
                    .uri(uri)
                    .timeout(Duration.ofMillis(fastapiRequestTimeoutMs))
                    .GET()
                    .build();

            HttpResponse<String> response = HTTP.send(request, HttpResponse.BodyHandlers.ofString());

            if (response.statusCode() != 200) {
                throw new RuntimeException("FastAPI server error (" + response.statusCode() + "): " + response.body());
            }

            JsonNode root = mapper.readTree(response.body());
            JsonNode cellsNode = root.get("cells");
            JsonNode queueNode = root.get("driversQueue");

            if (cellsNode == null || !cellsNode.isArray()) {
                throw new RuntimeException("FastAPI bingo payload missing 'cells' array");
            }
            if (queueNode == null || !queueNode.isArray()) {
                throw new RuntimeException("FastAPI bingo payload missing 'driversQueue' array");
            }

            long t2 = System.currentTimeMillis();

            // 3) Build entities in-memory
            BingoGame game = new BingoGame();
            game.setFinished(false);
            game.setStartedAt(LocalDateTime.now());
            game.setDurationSeconds(60);

            // 9 casillas
            int idx = 0;
            for (JsonNode cellNode : cellsNode) {
                BingoCell cell = new BingoCell();
                cell.setGame(game);
                cell.setCellIndex(idx++);
                cell.setThemeCode(cellNode.path("code").asText());
                cell.setThemeDescription(cellNode.path("description").asText());

                if (cellNode.hasNonNull("image")) {
                    cell.setThemeImage(cellNode.get("image").asText());
                }

                // ✅ Guardar SOLO ids en JSON (sin miles de BingoCellPilot)
                JsonNode vpi = cellNode.get("validPilotIds");
                JsonNode vp = cellNode.get("validPilots");

                if (vpi != null && vpi.isArray()) {
                    cell.setValidPilotIds(vpi.toString());
                } else if (vp != null && vp.isArray()) {
                    StringBuilder sb = new StringBuilder("[");
                    boolean first = true;
                    for (JsonNode pilotNode : vp) {
                        if (!first) sb.append(",");
                        sb.append(pilotNode.get("driverId").asLong());
                        first = false;
                    }
                    sb.append("]");
                    cell.setValidPilotIds(sb.toString());
                } else {
                    throw new RuntimeException("Bingo cell missing validPilotIds/validPilots");
                }

                game.getCells().add(cell);
            }

            // cola de 60 (si tu entity la persiste como tabla, aquí se generan ~60 inserts)
            int q = 0;
            for (JsonNode d : queueNode) {
                BingoGameDriver gd = new BingoGameDriver();
                gd.setGame(game);
                gd.setQueueIndex(q++);
                gd.setDriverId(d.path("driverId").asLong());
                gd.setDriverName(d.path("driverName").asText());
                game.getDriversQueue().add(gd);
            }

            long t3 = System.currentTimeMillis();

            // 4) Save (aquí suele estar el cuello de botella si no hay batching)
            BingoGame saved = gameDao.save(game);

            // 5) Registrar cooldown
            cooldownService.registerPlay("Bingo", userId);

            long t4 = System.currentTimeMillis();

            // ✅ Timing log para detectar dónde se va el tiempo
            log.info(
                    "BINGO start timings: cooldown={}ms fastapi={}ms build={}ms save+cooldown={}ms total={}ms (lang={}, userId={})",
                    (t1 - t0),
                    (t2 - t1),
                    (t3 - t2),
                    (t4 - t3),
                    (t4 - t0),
                    safeLang,
                    userId
            );

            return saved;

        } catch (CooldownException ce) {
            // dejamos pasar tal cual si ya lo manejas arriba en controllers/advice
            throw ce;
        } catch (Exception e) {
            long tEnd = System.currentTimeMillis();
            log.warn("BINGO start failed after {}ms (userId={}): {}", (tEnd - t0), userId, e.toString());
            throw new RuntimeException("Error calling FastAPI bingo generator", e);
        }
    }

    @Override
    public BingoSelectResponseDto selectCell(BingoSelectRequestDto dto) {
        BingoGame game = gameDao.findById(dto.getGameId()).orElseThrow();

        if (game.isFinished()) {
            return new BingoSelectResponseDto(false, true, "GAME_FINISHED");
        }

        // bloqueos básicos
        if (selectionDao.existsByGameIdAndCellId(dto.getGameId(), dto.getCellId())) {
            return new BingoSelectResponseDto(false, false, "CELL_ALREADY_FILLED");
        }
        if (selectionDao.existsByGameIdAndDriverId(dto.getGameId(), dto.getDriverId())) {
            return new BingoSelectResponseDto(false, false, "DRIVER_ALREADY_USED");
        }

        // ✅ validación sin tabla BingoCellPilot: membership en validPilotIds (JSON)
        BingoCell cell = cellDao.findById(dto.getCellId()).orElseThrow();

        String jsonIds = cell.getValidPilotIds();
        if (jsonIds == null || jsonIds.isBlank()) {
            return new BingoSelectResponseDto(false, false, "INCORRECT");
        }

        boolean ok;
        try {
            Long[] ids = mapper.readValue(jsonIds, Long[].class);
            ok = false;
            for (Long id : ids) {
                if (id != null && id.equals(dto.getDriverId())) {
                    ok = true;
                    break;
                }
            }
        } catch (Exception ex) {
            return new BingoSelectResponseDto(false, false, "INCORRECT");
        }

        if (!ok) {
            return new BingoSelectResponseDto(false, false, "INCORRECT");
        }

        // guardar acierto
        BingoSelection sel = new BingoSelection();
        sel.setGame(game);

        BingoCell cellRef = new BingoCell();
        cellRef.setId(dto.getCellId());
        sel.setCell(cellRef);

        sel.setDriverId(dto.getDriverId());
        sel.setDriverName(dto.getDriverName());

        selectionDao.save(sel);

        // comprobar fin (9 casillas)
        boolean finished = selectionDao.countByGameId(dto.getGameId()) >= 9;
        if (finished) {
            game.setFinished(true);
            gameDao.save(game);
        }

        return new BingoSelectResponseDto(true, finished, "CORRECT");
    }

    @Override
    public BingoGame finish(Long gameId) {
        BingoGame game = gameDao.findById(gameId).orElseThrow();
        game.setFinished(true);
        return gameDao.save(game);
    }
}
