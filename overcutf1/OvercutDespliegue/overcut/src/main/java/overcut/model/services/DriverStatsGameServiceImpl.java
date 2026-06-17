package overcut.model.services;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.transaction.Transactional;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import overcut.model.entities.DriverStatsGame;
import overcut.model.entities.DriverStatsGameDao;
import overcut.model.services.exceptions.CooldownException;
import overcut.rest.dtos.*;

import java.net.URI;
import java.net.URLEncoder;
import java.net.http.*;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;

@Service
@Transactional
public class DriverStatsGameServiceImpl implements DriverStatsGameService {

    @Autowired private DriverStatsGameDao gameDao;

    private static final ObjectMapper mapper = new ObjectMapper();

    @Autowired private CooldownService cooldownService;

    @Value("${fastapi.base-url:http://fastapi:8000}")
    private String fastapiBaseUrl;

    @Override
    public DriverStatsGameDto startGame(String lang, Long userId) {
        try {

            if (!cooldownService.canPlay("DriverStats", userId)) {
                long wait = cooldownService.secondsUntilNextPlay("DriverStats", userId);
                throw new CooldownException("WAIT", wait);
            }

            String url = fastapiBaseUrl + "/generate-driver-stats?lang=" +
                    URLEncoder.encode(lang, StandardCharsets.UTF_8);

            HttpRequest request = HttpRequest.newBuilder()
                    .uri(URI.create(url))
                    .GET()
                    .timeout(Duration.ofSeconds(10))
                    .build();

            HttpClient client = HttpClient.newHttpClient();
            HttpResponse<String> response = client.send(request, HttpResponse.BodyHandlers.ofString());

            // ✅ Chequeo de status + body válido
            if (response.statusCode() < 200 || response.statusCode() >= 300) {
                throw new RuntimeException("FastAPI generate-driver-stats failed: HTTP " + response.statusCode()
                        + " body=" + response.body());
            }

            JsonNode root = mapper.readTree(response.body());

            JsonNode did = root.get("driverId");
            JsonNode dname = root.get("driverName");
            if (did == null || dname == null) {
                throw new RuntimeException("FastAPI response missing driverId/driverName: body=" + response.body());
            }

            long driverId = did.asLong();
            String driverName = dname.asText();

            DriverStatsGame game = new DriverStatsGame();
            game.setUserId(userId);
            game.setDriverId(driverId);
            game.setDriverName(driverName);

            DriverStatsGame saved = gameDao.save(game);

            cooldownService.registerPlay("DriverStats", userId);

            DriverStatsGameDto dto = new DriverStatsGameDto();
            dto.setId(saved.getId());
            dto.setDriverName(saved.getDriverName());
            dto.setFinished(saved.isFinished());
            dto.setCorrectCount(saved.getCorrectCount());
            dto.setDetails(null);
            return dto;

        } catch (Exception e) {
            throw new RuntimeException("Error al iniciar DriverStatsGame", e);
        }
    }

    @Override
    public DriverStatsGameDto submit(Long userId, DriverStatsSubmitRequestDto req) {
        try {
            DriverStatsGame game = gameDao.findById(req.getGameId()).orElseThrow();

            // Seguridad mínima
            if (!game.getUserId().equals(userId)) {
                throw new RuntimeException("Not your game");
            }
            if (game.isFinished()) {
                return toDto(game, null);
            }

            DriverStatsAnswersDto a = req.getAnswers();
            if (a == null) throw new RuntimeException("Missing answers");

            // Guardamos lo enviado (como en otros juegos)
            game.setUserWins(a.getWins());
            game.setUserPodiums(a.getPodiums());
            game.setUserTeams(a.getTeams());
            game.setUserTitles(a.getTitles());
            game.setUserSeasons(a.getSeasons());
            game.setUserRacesBin(a.getRacesBin());
            game.setUserPointsBin(a.getPointsBin());

            // Payload a FastAPI para validar contra stats reales del driverId
            var payload = mapper.createObjectNode();
            payload.put("driverId", game.getDriverId());
            payload.put("lang", (req.getLang() != null && !req.getLang().isBlank()) ? req.getLang() : "es");
            payload.set("answers", mapper.valueToTree(a));

            HttpRequest request = HttpRequest.newBuilder()
                    .uri(URI.create(fastapiBaseUrl + "/validate-driver-stats"))
                    .header("Content-Type", "application/json")
                    .POST(HttpRequest.BodyPublishers.ofString(mapper.writeValueAsString(payload)))
                    .timeout(Duration.ofSeconds(20))
                    .build();

           HttpClient client = HttpClient.newBuilder()
            .version(HttpClient.Version.HTTP_1_1)
            .connectTimeout(Duration.ofSeconds(5))
            .build();
            HttpResponse<String> response = client.send(request, HttpResponse.BodyHandlers.ofString());

            String body = response.body();

            // ✅ Logs útiles para depurar (déjalo mientras pruebas)
            System.out.println("[DriverStats] validate status=" + response.statusCode());
            System.out.println("[DriverStats] validate body=" + body);

            // ✅ Chequeo de status
            if (response.statusCode() < 200 || response.statusCode() >= 300) {
                throw new RuntimeException("FastAPI validate-driver-stats failed: HTTP " + response.statusCode()
                        + " body=" + body);
            }

            JsonNode root = mapper.readTree(body);

            // FastAPI puede devolver {"error":"..."}
            JsonNode err = root.get("error");
            if (err != null && !err.isNull()) {
                throw new RuntimeException("FastAPI error: " + err.asText() + " body=" + body);
            }

            JsonNode cc = root.get("correctCount");
            if (cc == null || cc.isNull()) {
                throw new RuntimeException("FastAPI response missing correctCount. body=" + body);
            }
            int correctCount = cc.asInt();

            List<DriverStatsDetailDto> details = new ArrayList<>();
            JsonNode det = root.get("details");
            if (det != null && det.isArray()) {
                for (JsonNode d : det) {
                    DriverStatsDetailDto dd = new DriverStatsDetailDto();
                    // ✅ path(...) evita NPE si falta un campo
                    dd.setLabel(d.path("label").asText(""));
                    dd.setUser(d.path("user").asText(""));
                    dd.setActual(d.path("actual").asText(""));
                    dd.setCorrect(d.path("correct").asBoolean(false));
                    details.add(dd);
                }
            }

            game.setCorrectCount(correctCount);
            game.setFinished(true);
            game.setFinishedAt(LocalDateTime.now());

            DriverStatsGame saved = gameDao.save(game);

            DriverStatsGameDto dto = toDto(saved, details);
            dto.setCorrectCount(correctCount);
            return dto;

        } catch (Exception e) {
            throw new RuntimeException("Error al enviar respuestas DriverStatsGame", e);
        }
    }

    @Override
    public DriverStatsGameDto getGame(Long gameId) {
        DriverStatsGame game = gameDao.findById(gameId).orElseThrow();
        return toDto(game, null);
    }

    private DriverStatsGameDto toDto(DriverStatsGame g, List<DriverStatsDetailDto> details) {
        DriverStatsGameDto dto = new DriverStatsGameDto();
        dto.setId(g.getId());
        dto.setDriverName(g.getDriverName());
        dto.setFinished(g.isFinished());
        dto.setCorrectCount(g.getCorrectCount());
        dto.setDetails(details);
        return dto;
    }
}
