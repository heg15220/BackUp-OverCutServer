package overcut.model.services;

import overcut.model.entities.ThirtySecondsGame;
import java.util.List;
import overcut.rest.dtos.PilotSuggestionDto;

public interface ThirtySecondsGameService {
    ThirtySecondsGame startGame(Long userId, String lang);
    ThirtySecondsGame submitAnswers(Long gameId, List<String> answers);
    ThirtySecondsGame getGameStatus(Long gameId);
    List<PilotSuggestionDto> autocompletePilotNames(String partial);
}
