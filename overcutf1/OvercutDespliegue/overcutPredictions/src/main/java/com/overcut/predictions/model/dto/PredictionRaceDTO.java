package com.overcut.predictions.model.dto;

import java.util.List;

public class PredictionRaceDTO {

    private Long raceId;
    private Integer round;
    private String raceName;

    private List<PredictionResultDTO> results;

    private List<PredictionResultDTO> sprintResults;

    private boolean hasSprint;

    public Long getRaceId() {
        return raceId;
    }

    public void setRaceId(Long raceId) {
        this.raceId = raceId;
    }

    public Integer getRound() {
        return round;
    }

    public void setRound(Integer round) {
        this.round = round;
    }

    public String getRaceName() {
        return raceName;
    }

    public void setRaceName(String raceName) {
        this.raceName = raceName;
    }

    public List<PredictionResultDTO> getResults() {
        return results;
    }

    public void setResults(List<PredictionResultDTO> results) {
        this.results = results;
    }

    public List<PredictionResultDTO> getSprintResults() {
        return sprintResults;
    }

    public void setSprintResults(List<PredictionResultDTO> sprintResults) {
        this.sprintResults = sprintResults;
    }

    public boolean isHasSprint() {
        return hasSprint;
    }

    public void setHasSprint(boolean hasSprint) {
        this.hasSprint = hasSprint;
    }
}
