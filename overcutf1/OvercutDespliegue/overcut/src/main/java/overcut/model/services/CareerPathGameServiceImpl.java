package overcut.model.services;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import overcut.model.entities.CareerPathClue;
import overcut.model.entities.CareerPathGame;
import overcut.model.entities.CareerPathGameDao;
import overcut.model.entities.CareerPathClueDao;
import java.net.URI;
import jakarta.transaction.Transactional;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import overcut.model.services.exceptions.CooldownException;

import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import java.util.ArrayList;
import java.util.List;
import org.springframework.beans.factory.annotation.Value;

@Service
@Transactional
public class CareerPathGameServiceImpl implements CareerPathGameService {

    @Autowired private CareerPathGameDao gameDao;
    @Autowired private CareerPathClueDao clueDao;
    @Autowired private CooldownService cooldownService;

    @Value("${fastapi.base-url:http://fastapi:8000}")
    private String fastapiBaseUrl;

    private static final ObjectMapper MAPPER = new ObjectMapper();

    private HttpClient http() {
        return HttpClient.newBuilder()
                .connectTimeout(Duration.ofSeconds(3))
                .build();
    }

    @Override
    public CareerPathGame startGame(Long userId) {
        if (!cooldownService.canPlay("CareerPath", userId)) {
            long wait = cooldownService.secondsUntilNextPlay("CareerPath", userId);
            throw new CooldownException("WAIT", wait);
        }

        try {
            // ✅ Endpoint correcto para CareerPath
            String url = fastapiBaseUrl + "/generate-career-path";

            HttpRequest request = HttpRequest.newBuilder()
                    .uri(URI.create(url))
                    .timeout(Duration.ofSeconds(6))
                    .GET()
                    .build();

            HttpResponse<String> response = http().send(request, HttpResponse.BodyHandlers.ofString());
            if (response.statusCode() != 200) {
                throw new RuntimeException("FastAPI error (" + response.statusCode() + "): " + response.body());
            }

            JsonNode result = MAPPER.readTree(response.body());

            // ✅ Validación defensiva de esquema
            JsonNode driverIdNode   = result.get("driverId");
            JsonNode driverNameNode = result.get("driverName");
            JsonNode teamsNode      = result.get("teams");

            if (driverIdNode == null || driverNameNode == null || teamsNode == null || !teamsNode.isArray()) {
                throw new RuntimeException(
                    "Respuesta inválida de FastAPI en /generate-career-path. Body: " + response.body()
                );
            }

            CareerPathGame game = new CareerPathGame();

            // ✅ asegúrate de que la lista existe
            if (game.getClues() == null) {
                game.setClues(new ArrayList<>());
            }

            game.setDriverId(driverIdNode.asLong());
            game.setDriverName(driverNameNode.asText());

            int clueOrder = 0;
            for (JsonNode teamNode : teamsNode) {
                CareerPathClue clue = new CareerPathClue();
                clue.setGame(game);
                clue.setTeamName(teamNode.asText());
                clue.setClueOrder(clueOrder++);
                game.getClues().add(clue);
            }

            CareerPathGame saved = gameDao.save(game);
            cooldownService.registerPlay("CareerPath", userId);
            return saved;

        } catch (Exception e) {
            // deja rastro del endpoint para diagnóstico
            throw new RuntimeException("Error iniciando CareerPathGame (endpoint: " 
                    + fastapiBaseUrl + "/generate-career-path)", e);
        }
    }

    @Override
    public CareerPathGame guessDriver(Long gameId, String driverGuess) {
        CareerPathGame game = gameDao.findById(gameId).orElseThrow();
        boolean isCorrect = driverGuess != null && driverGuess.equalsIgnoreCase(game.getDriverName());

        if (isCorrect || game.getCurrentClueIndex() >= game.getClues().size() - 1) {
            game.setFinished(true);
            game.setSuccessful(isCorrect);
        } else {
            game.setCurrentClueIndex(game.getCurrentClueIndex() + 1);
        }

        return gameDao.save(game);
    }

    @Override
    public CareerPathGame getGameStatus(Long gameId) {
        return gameDao.findById(gameId).orElseThrow();
    }

    @Override
    public List<String> autocompletePilotNames(String partial) {
        try {
            String encoded = java.net.URLEncoder.encode(partial, java.nio.charset.StandardCharsets.UTF_8);
            // ✅ usa siempre fastapiBaseUrl y el endpoint correcto
            String url = fastapiBaseUrl + "/autocomplete-career-pilot?partial=" + encoded;

            HttpRequest request = HttpRequest.newBuilder()
                    .uri(URI.create(url))
                    .timeout(Duration.ofSeconds(6))
                    .GET()
                    .build();

            HttpResponse<String> response = http().send(request, HttpResponse.BodyHandlers.ofString());
            if (response.statusCode() != 200) {
                throw new RuntimeException("FastAPI error (" + response.statusCode() + "): " + response.body());
            }

            return MAPPER.readValue(response.body(), new TypeReference<List<String>>() {});
        } catch (Exception e) {
            throw new RuntimeException("Error en autocompleteCareerPath (endpoint: "
                    + fastapiBaseUrl + "/autocomplete-career-pilot)", e);
        }
    }

    @Override
    public CareerPathGame skipClue(Long gameId) {
        CareerPathGame game = gameDao.findById(gameId).orElseThrow();
        if (!game.isFinished() && game.getCurrentClueIndex() < game.getClues().size() - 1) {
            game.setCurrentClueIndex(game.getCurrentClueIndex() + 1);
        }
        return gameDao.save(game);
    }
}

