package com.overcut.predictions.model.dto;

import java.util.List;
import java.util.Map;

public class PredictionBootstrapDTO {

    private Integer season;
    private Integer simulatedFromRound;
    private Integer totalRounds;

    private List<PredictionRaceDTO> completedRaces;

    private List<StandingsEntryDTO> driverStandings;
    private List<StandingsEntryDTO> constructorStandings;

    private PredictionLookupsDTO lookups;

    private Map<Long, Long> driverToConstructor;

    private String mode; // "db" | "custom" | "empty_db"
    private Integer pointsEra;

    // ✅ si vienes de /bootstrap-custom
    private PredictionBootstrapCustomRequestDTO customConfig;

    /**
     * ✅ NUEVO:
     * Lista de rondas que tienen Sprint en esta temporada (calendario real en BD).
     * Ej: [5, 11, 15, ...]
     */
    private List<Integer> sprintRounds;

    public Integer getSeason() {
        return season;
    }

    public void setSeason(Integer season) {
        this.season = season;
    }

    public Integer getSimulatedFromRound() {
        return simulatedFromRound;
    }

    public void setSimulatedFromRound(Integer simulatedFromRound) {
        this.simulatedFromRound = simulatedFromRound;
    }

    public Integer getTotalRounds() {
        return totalRounds;
    }

    public void setTotalRounds(Integer totalRounds) {
        this.totalRounds = totalRounds;
    }

    public List<PredictionRaceDTO> getCompletedRaces() {
        return completedRaces;
    }

    public void setCompletedRaces(List<PredictionRaceDTO> completedRaces) {
        this.completedRaces = completedRaces;
    }

    public List<StandingsEntryDTO> getDriverStandings() {
        return driverStandings;
    }

    public void setDriverStandings(List<StandingsEntryDTO> driverStandings) {
        this.driverStandings = driverStandings;
    }

    public List<StandingsEntryDTO> getConstructorStandings() {
        return constructorStandings;
    }

    public void setConstructorStandings(List<StandingsEntryDTO> constructorStandings) {
        this.constructorStandings = constructorStandings;
    }

    public PredictionLookupsDTO getLookups() {
        return lookups;
    }

    public void setLookups(PredictionLookupsDTO lookups) {
        this.lookups = lookups;
    }

    public Map<Long, Long> getDriverToConstructor() {
        return driverToConstructor;
    }

    public void setDriverToConstructor(Map<Long, Long> driverToConstructor) {
        this.driverToConstructor = driverToConstructor;
    }

    public String getMode() {
        return mode;
    }

    public void setMode(String mode) {
        this.mode = mode;
    }

    public Integer getPointsEra() {
        return pointsEra;
    }

    public void setPointsEra(Integer pointsEra) {
        this.pointsEra = pointsEra;
    }

    public PredictionBootstrapCustomRequestDTO getCustomConfig() {
        return customConfig;
    }

    public void setCustomConfig(PredictionBootstrapCustomRequestDTO customConfig) {
        this.customConfig = customConfig;
    }

    public List<Integer> getSprintRounds() {
        return sprintRounds;
    }

    public void setSprintRounds(List<Integer> sprintRounds) {
        this.sprintRounds = sprintRounds;
    }
}
