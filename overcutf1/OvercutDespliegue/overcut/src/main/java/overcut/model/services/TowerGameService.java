package overcut.model.services;

import overcut.rest.dtos.PilotSuggestionDto;
import overcut.rest.dtos.TowerAnswerRequest;
import overcut.rest.dtos.TowerGameDto;
import overcut.rest.dtos.TowerGuessRequest;
import overcut.rest.dtos.TowerHintResponse;
import overcut.rest.dtos.TowerGuessV2Request;

import java.util.List;

public interface TowerGameService {

    Object getThemes();

    TowerGameDto startGame(String lang, String themeType, String themeKey, Long userId);

    TowerGameDto guess(TowerGuessRequest req, Long userId);

    TowerHintResponse hint(Long gameId, Long userId);

    TowerGameDto getStatus(Long gameId, Long userId);

    // ✅ ANTES: List<String>
    // ✅ AHORA: List<PilotSuggestionDto>
    List<PilotSuggestionDto> autocompletePilots(Long gameId, String query, Long userId);

    TowerGameDto answer(TowerAnswerRequest req, Long userId);

    TowerGameDto guessV2(TowerGuessV2Request req, Long userId);
}
