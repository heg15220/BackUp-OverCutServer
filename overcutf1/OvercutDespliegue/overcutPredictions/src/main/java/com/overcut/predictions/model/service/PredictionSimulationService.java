package com.overcut.predictions.model.service;

import com.overcut.predictions.model.dto.*;
import com.overcut.predictions.model.rules.PointsSystem;
import com.overcut.predictions.model.rules.SprintPointsSystem;
import com.overcut.predictions.model.simulation.*;

import org.springframework.stereotype.Service;

import java.util.*;

@Service
public class PredictionSimulationService {

    public SimulationResultDTO applySimulation(
            SimulationState state,
            PointsSystem pointsSystem,
            SprintPointsSystem sprintPointsSystem,
            SimulationRaceInputDTO input,
            Map<Long, Long> driverToConstructor
    ) {

        SimulationEngine engine =
                new SimulationEngine(
                        state,
                        pointsSystem,
                        sprintPointsSystem,
                        driverToConstructor
                );

        // ✅ Sprint primero (si existe)
        if (input.getOrderedDriverIdsSprint() != null && !input.getOrderedDriverIdsSprint().isEmpty()) {
            engine.applySprint(input.getOrderedDriverIdsSprint());
        }

        // ✅ Carrera
        engine.applyRace(input.getOrderedDriverIds());

        SimulationResultDTO result = new SimulationResultDTO();
        result.setDriverStandings(buildStandings(state.getDriverPoints()));
        result.setConstructorStandings(buildStandings(state.getConstructorPoints()));
        return result;
    }

    public SimulationResultDTO applySimulationBatch(
            SimulationState state,
            PointsSystem pointsSystem,
            SprintPointsSystem sprintPointsSystem,
            List<SimulationRaceInputDTO> races,
            Map<Long, Long> driverToConstructor
    ) {

        SimulationEngine engine =
                new SimulationEngine(
                        state,
                        pointsSystem,
                        sprintPointsSystem,
                        driverToConstructor
                );

        for (SimulationRaceInputDTO race : races) {
            if (race.getOrderedDriverIdsSprint() != null && !race.getOrderedDriverIdsSprint().isEmpty()) {
                engine.applySprint(race.getOrderedDriverIdsSprint());
            }
            engine.applyRace(race.getOrderedDriverIds());
        }

        SimulationResultDTO result = new SimulationResultDTO();
        result.setDriverStandings(buildStandings(state.getDriverPoints()));
        result.setConstructorStandings(buildStandings(state.getConstructorPoints()));
        return result;
    }

    private List<StandingsEntryDTO> buildStandings(Map<Long, Integer> pointsMap) {
        List<StandingsEntryDTO> list = new ArrayList<>();
        for (Map.Entry<Long, Integer> e : pointsMap.entrySet()) {
            list.add(new StandingsEntryDTO(e.getKey(), e.getValue()));
        }
        list.sort((a, b) -> b.getPoints().compareTo(a.getPoints()));
        return list;
    }
}
