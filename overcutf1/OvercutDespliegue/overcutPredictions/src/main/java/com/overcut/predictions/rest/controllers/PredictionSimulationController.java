package com.overcut.predictions.rest.controllers;

import com.overcut.predictions.model.dto.*;
import com.overcut.predictions.model.rules.PointsSystem;
import com.overcut.predictions.model.rules.PointsSystemFactory;
import com.overcut.predictions.model.rules.SprintPointsSystem;
import com.overcut.predictions.model.rules.SprintPointsMode;
import com.overcut.predictions.model.service.PredictionSimulationService;
import com.overcut.predictions.model.simulation.SimulationState;

import org.springframework.web.bind.annotation.*;

@CrossOrigin(origins = {"https://overcutf1.com", "http://localhost:8086"})
@RestController
@RequestMapping("/api/predictions/simulate")
public class PredictionSimulationController {

    private final PredictionSimulationService simulationService;

    public PredictionSimulationController(PredictionSimulationService simulationService) {
        this.simulationService = simulationService;
    }

    @PostMapping("/apply")
    public SimulationResultDTO applySimulation(@RequestBody SimulationApplyRequestDTO request) {

        SimulationState state = new SimulationState();

        if (request.getDriverStandings() != null) {
            for (StandingsEntryDTO e : request.getDriverStandings()) {
                state.getDriverPoints().put(e.getEntityId(), e.getPoints());
            }
        }

        if (request.getConstructorStandings() != null) {
            for (StandingsEntryDTO e : request.getConstructorStandings()) {
                state.getConstructorPoints().put(e.getEntityId(), e.getPoints());
            }
        }

        int key = (request.getPointsEra() != null ? request.getPointsEra() : request.getSeason());
        PointsSystem pointsSystem = PointsSystemFactory.forSeason(key);

        // ✅ Sprint mode configurable (default TOP8)
        SprintPointsMode sprintMode = request.getSprintPointsMode();
        SprintPointsSystem sprintPointsSystem = new SprintPointsSystem(sprintMode);

        return simulationService.applySimulation(
                state,
                pointsSystem,
                sprintPointsSystem,
                request.getRace(),
                request.getDriverToConstructor()
        );
    }

    @PostMapping("/apply-batch")
    public SimulationResultDTO applySimulationBatch(@RequestBody SimulationApplyBatchRequestDTO request) {

        SimulationState state = new SimulationState();

        if (request.getDriverStandings() != null) {
            for (StandingsEntryDTO e : request.getDriverStandings()) {
                state.getDriverPoints().put(e.getEntityId(), e.getPoints());
            }
        }

        if (request.getConstructorStandings() != null) {
            for (StandingsEntryDTO e : request.getConstructorStandings()) {
                state.getConstructorPoints().put(e.getEntityId(), e.getPoints());
            }
        }

        int key = (request.getPointsEra() != null ? request.getPointsEra() : request.getSeason());
        PointsSystem pointsSystem = PointsSystemFactory.forSeason(key);

        SprintPointsMode sprintMode = request.getSprintPointsMode();
        SprintPointsSystem sprintPointsSystem = new SprintPointsSystem(sprintMode);

        return simulationService.applySimulationBatch(
                state,
                pointsSystem,
                sprintPointsSystem,
                request.getRaces(),
                request.getDriverToConstructor()
        );
    }
}
