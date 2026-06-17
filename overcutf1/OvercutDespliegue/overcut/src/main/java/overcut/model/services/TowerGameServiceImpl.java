package overcut.model.services;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.transaction.Transactional;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import overcut.model.entities.*;
import overcut.model.services.exceptions.CooldownException;
import overcut.rest.dtos.*;

import java.net.URI;
import java.net.URLEncoder;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.time.LocalDateTime;
import java.util.List;

@Service
@Transactional
public class TowerGameServiceImpl implements TowerGameService {

    @Autowired private TowerGameDao gameDao;
    @Autowired private TowerAttemptDao attemptDao;
    @Autowired private CooldownService cooldownService;

    @Autowired private TowerValidationClient towerValidationClient;

    private static final String COOLDOWN_KEY = "Tower";

    private final ObjectMapper mapper = new ObjectMapper();
    private final HttpClient client = HttpClient.newHttpClient();

    @Value("${fastapi.base-url:http://fastapi:8000}")
    private String fastapiBaseUrl;

    @Override
    public Object getThemes() {
        try {
            HttpRequest req = HttpRequest.newBuilder()
                    .uri(URI.create(fastapiBaseUrl + "/tower-themes"))
                    .GET()
                    .build();

            HttpResponse<String> res = client.send(req, HttpResponse.BodyHandlers.ofString(StandardCharsets.UTF_8));
            if (res.statusCode() != 200) throw new RuntimeException("FastAPI error: " + res.body());

            return mapper.readTree(res.body());
        } catch (Exception e) {
            throw new RuntimeException("Error loading Tower themes", e);
        }
    }

    @Override
    public TowerGameDto startGame(String lang, String themeType, String themeKey, Long userId) {
        if (!cooldownService.canPlay(COOLDOWN_KEY, userId)) {
            long wait = cooldownService.secondsUntilNextPlay(COOLDOWN_KEY, userId);
            throw new CooldownException("WAIT", wait);
        }

        try {
            String url = fastapiBaseUrl + "/generate-tower";

            if (themeType != null && !themeType.isBlank()) {
                url += "?themeType=" + URLEncoder.encode(themeType, StandardCharsets.UTF_8);
                if (themeKey != null && !themeKey.isBlank()) {
                    url += "&themeKey=" + URLEncoder.encode(themeKey, StandardCharsets.UTF_8);
                }
            }

            HttpRequest req = HttpRequest.newBuilder()
                    .uri(URI.create(url))
                    .GET()
                    .build();

            HttpResponse<String> res = client.send(req, HttpResponse.BodyHandlers.ofString(StandardCharsets.UTF_8));
            if (res.statusCode() != 200) throw new RuntimeException("FastAPI error: " + res.body());

            JsonNode root = mapper.readTree(res.body());

            TowerGame game = new TowerGame();
            game.setCreatedAt(LocalDateTime.now());
            game.setLang(lang);
            game.setThemeType(root.get("themeType").asText());

            JsonNode keyNode = root.get("themeKey");
            game.setThemeKey(keyNode.isTextual() ? keyNode.asText() : keyNode.toString());

            game.setHintUsed(false);
            game.setAttempts(0);
            game.setFinished(false);

            TowerGame saved = gameDao.save(game);

            cooldownService.registerPlay(COOLDOWN_KEY, userId);
            return TowerConversor.toGameDto(saved, List.of());

        } catch (Exception e) {
            throw new RuntimeException("Error starting Tower game", e);
        }
    }

    @Override
    public TowerGameDto guess(TowerGuessRequest req, Long userId) {
        try {
            TowerGame game = gameDao.findById(req.gameId).orElseThrow();

            // evitar repetir el mismo nombre
            if (attemptDao.existsByGame_IdAndDriverNameIgnoreCase(game.getId(), req.driverName)) {
                List<TowerAttempt> history = attemptDao.findByGame_IdOrderByCreatedAtAsc(game.getId());
                return TowerConversor.toGameDto(game, history);
            }

            // ✅ payload
            var node = mapper.createObjectNode()
                    .put("themeType", game.getThemeType())
                    .put("driverName", req.driverName == null ? "" : req.driverName)
                    .put("lang", game.getLang());

            if (req.driverId != null) node.put("driverId", req.driverId);
            else node.putNull("driverId");

            if ("decade".equals(game.getThemeType())) {
                node.set("themeKey", mapper.readTree(game.getThemeKey()));
            } else {
                node.put("themeKey", game.getThemeKey());
            }

            String payload = node.toString();

            HttpRequest httpReq = HttpRequest.newBuilder()
                    .uri(URI.create(fastapiBaseUrl + "/validate-tower"))
                    .header("Content-Type", "application/json; charset=utf-8")
                    .header("Accept", "application/json")
                    .POST(HttpRequest.BodyPublishers.ofString(payload, StandardCharsets.UTF_8))
                    .build();

            HttpResponse<String> httpRes = client.send(httpReq, HttpResponse.BodyHandlers.ofString(StandardCharsets.UTF_8));
            if (httpRes.statusCode() != 200) throw new RuntimeException("FastAPI error: " + httpRes.body());

            JsonNode root = mapper.readTree(httpRes.body());
            boolean valid = root.get("valid").asBoolean();

            // ✅ FIX: driverName no puede ser null en BD
            String driverName = (req.driverName == null ? "" : req.driverName);

            TowerAttempt a = new TowerAttempt();
            a.setGame(game);
            a.setDriverId(req.driverId);
            a.setDriverName(driverName);
            a.setValid(valid);
            attemptDao.save(a);

            game.setAttempts(game.getAttempts() + 1);
            gameDao.save(game);

            List<TowerAttempt> history = attemptDao.findByGame_IdOrderByCreatedAtAsc(game.getId());
            return TowerConversor.toGameDto(game, history);

        } catch (Exception e) {
            throw new RuntimeException("Error validating Tower guess", e);
        }
    }

    @Override
    public TowerGameDto guessV2(TowerGuessV2Request req, Long userId) {
        TowerGame game = gameDao.findById(req.gameId).orElseThrow();

        if (game.isFinished()) {
            List<TowerAttempt> history = attemptDao.findByGame_IdOrderByCreatedAtAsc(game.getId());
            return TowerConversor.toGameDto(game, history);
        }

        if (req.driverId == null || req.driverId <= 0) {
            throw new IllegalArgumentException("driverId requerido");
        }

        // evita duplicados por ID
        if (attemptDao.existsByGame_IdAndDriverId(game.getId(), req.driverId)) {
            List<TowerAttempt> history = attemptDao.findByGame_IdOrderByCreatedAtAsc(game.getId());
            return TowerConversor.toGameDto(game, history);
        }

        // themeKey JSON node (porque decade es json)
        JsonNode themeKeyNode;
        try {
            if ("decade".equals(game.getThemeType())) {
                themeKeyNode = mapper.readTree(game.getThemeKey());
            } else {
                themeKeyNode = mapper.getNodeFactory().textNode(game.getThemeKey());
            }
        } catch (Exception e) {
            throw new RuntimeException("Invalid themeKey stored", e);
        }

        boolean valid = towerValidationClient.validate(
                game.getThemeType(),
                themeKeyNode,
                req.driverId,
                game.getLang()
        );

        // ✅ FIX DEFINITIVO:
        // OvercutDB NO tiene tabla drivers, así que NO resolvemos nombre en BD.
        // Guardamos el nombre que venga del frontend/autocomplete (si no viene -> "").
        String driverName = (req.driverName == null ? "" : req.driverName);

        TowerAttempt a = new TowerAttempt();
        a.setGame(game);
        a.setDriverId(req.driverId);
        a.setDriverName(driverName); // NOT NULL siempre
        a.setValid(valid);
        attemptDao.save(a);

        game.setAttempts(game.getAttempts() + 1);
        gameDao.save(game);

        List<TowerAttempt> history = attemptDao.findByGame_IdOrderByCreatedAtAsc(game.getId());
        return TowerConversor.toGameDto(game, history);
    }

    @Override
    public TowerHintResponse hint(Long gameId, Long userId) {
        try {
            TowerGame game = gameDao.findById(gameId).orElseThrow();
            TowerHintResponse res = new TowerHintResponse();

            if (game.isHintUsed()) {
                res.ok = true;
                res.hintType = game.getThemeType();
                res.hintValue = fetchHintValueFromFastApi(game);
                return res;
            }

            if (game.getAttempts() < 15) {
                res.ok = false;
                res.hintType = null;
                res.hintValue = null;
                return res;
            }

            game.setHintUsed(true);
            gameDao.save(game);

            res.ok = true;
            res.hintType = game.getThemeType();
            res.hintValue = fetchHintValueFromFastApi(game);
            return res;

        } catch (Exception e) {
            throw new RuntimeException("Error resolving Tower hint", e);
        }
    }

    private String fetchHintValueFromFastApi(TowerGame game) {
        try {
            var node = mapper.createObjectNode()
                    .put("themeType", game.getThemeType())
                    .put("lang", game.getLang());

            if ("decade".equals(game.getThemeType())) {
                node.set("themeKey", mapper.readTree(game.getThemeKey()));
            } else {
                node.put("themeKey", game.getThemeKey());
            }

            String payload = node.toString();

            HttpRequest req = HttpRequest.newBuilder()
                    .uri(URI.create(fastapiBaseUrl + "/tower-hint-value"))
                    .header("Content-Type", "application/json; charset=utf-8")
                    .header("Accept", "application/json")
                    .POST(HttpRequest.BodyPublishers.ofString(payload, StandardCharsets.UTF_8))
                    .build();

            HttpResponse<String> resp = client.send(req, HttpResponse.BodyHandlers.ofString(StandardCharsets.UTF_8));
            if (resp.statusCode() != 200) {
                throw new RuntimeException("FastAPI error: " + resp.body());
            }

            JsonNode root = mapper.readTree(resp.body());
            return root.has("hintValue") && !root.get("hintValue").isNull()
                    ? root.get("hintValue").asText()
                    : null;

        } catch (Exception e) {
            return null;
        }
    }

    @Override
    public TowerGameDto getStatus(Long gameId, Long userId) {
        TowerGame game = gameDao.findById(gameId).orElseThrow();
        List<TowerAttempt> history = attemptDao.findByGame_IdOrderByCreatedAtAsc(gameId);
        return TowerConversor.toGameDto(game, history);
    }

    @Override
    public List<PilotSuggestionDto> autocompletePilots(Long gameId, String query, Long userId) {
        try {
            String url = fastapiBaseUrl + "/autocomplete-pilot-ids?partial=" +
                    URLEncoder.encode(query, StandardCharsets.UTF_8) + "&limit=10";

            HttpRequest request = HttpRequest.newBuilder()
                    .uri(URI.create(url))
                    .GET()
                    .build();

            HttpResponse<String> response = client.send(request, HttpResponse.BodyHandlers.ofString(StandardCharsets.UTF_8));
            if (response.statusCode() != 200) {
                throw new RuntimeException("FastAPI error: " + response.body());
            }

            JsonNode arr = mapper.readTree(response.body());
            if (arr == null || !arr.isArray()) return List.of();

            List<PilotSuggestionDto> out = new java.util.ArrayList<>();
            for (JsonNode n : arr) {
                Long driverId = n.hasNonNull("driverId") ? n.get("driverId").asLong() : null;
                String driverName = n.hasNonNull("driverName") ? n.get("driverName").asText() : null;

                if (driverId != null && driverName != null && !driverName.isBlank()) {
                    out.add(new PilotSuggestionDto(driverId, driverName));
                }
            }
            return out;

        } catch (Exception e) {
            throw new RuntimeException("Error al ejecutar autocomplete Tower (ids)", e);
        }
    }

    @Override
    public TowerGameDto answer(TowerAnswerRequest req, Long userId) {
        TowerGame game = gameDao.findById(req.gameId).orElseThrow();

        if (game.isFinished()) {
            List<TowerAttempt> history = attemptDao.findByGame_IdOrderByCreatedAtAsc(game.getId());
            return TowerConversor.toGameDto(game, history);
        }

        boolean ok = isAnswerCorrect(game, req.themeType, req.themeKey);

        game.setFinished(true);
        game.setSolved(ok);
        gameDao.save(game);

        List<TowerAttempt> history = attemptDao.findByGame_IdOrderByCreatedAtAsc(game.getId());
        return TowerConversor.toGameDto(game, history);
    }

    private boolean isAnswerCorrect(TowerGame game, String themeType, String themeKey) {
        if (themeType == null) return false;

        if (!themeType.equals(game.getThemeType())) return false;

        if ("champions".equals(game.getThemeType())) {
            return "world_champions".equals(game.getThemeKey());
        }

        if ("decade".equals(game.getThemeType())) {
            try {
                JsonNode saved = mapper.readTree(game.getThemeKey());
                String code = saved.has("code") ? saved.get("code").asText() : null;
                return code != null && code.equals(themeKey);
            } catch (Exception e) {
                return false;
            }
        }

        return themeKey != null && themeKey.equals(game.getThemeKey());
    }
}
