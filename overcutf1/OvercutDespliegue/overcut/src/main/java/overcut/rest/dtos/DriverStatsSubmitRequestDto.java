package overcut.rest.dtos;

public class DriverStatsSubmitRequestDto {
    private Long gameId;
    private DriverStatsAnswersDto answers;
    private String lang; // ✅ NUEVO

    public Long getGameId() { return gameId; }
    public void setGameId(Long gameId) { this.gameId = gameId; }

    public DriverStatsAnswersDto getAnswers() { return answers; }
    public void setAnswers(DriverStatsAnswersDto answers) { this.answers = answers; }

    public String getLang() { return lang; }
    public void setLang(String lang) { this.lang = lang; }
}
