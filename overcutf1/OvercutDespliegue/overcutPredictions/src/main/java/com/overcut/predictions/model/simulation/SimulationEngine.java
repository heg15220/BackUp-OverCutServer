package com.overcut.predictions.model.simulation;

import com.overcut.predictions.model.rules.PointsSystem;
import com.overcut.predictions.model.rules.SprintPointsSystem;

import java.util.List;
import java.util.Map;

public class SimulationEngine {

    private final SimulationState state;
    private final PointsSystem pointsSystem;
    private final SprintPointsSystem sprintPointsSystem;
    private final Map<Long, Long> driverToConstructor;

    public SimulationEngine(
            SimulationState state,
            PointsSystem pointsSystem,
            SprintPointsSystem sprintPointsSystem,
            Map<Long, Long> driverToConstructor
    ) {
        this.state = state;
        this.pointsSystem = pointsSystem;
        this.sprintPointsSystem = sprintPointsSystem;
        this.driverToConstructor = driverToConstructor;
    }

    public void applySprint(List<Long> orderedDriverIdsSprint) {
        if (orderedDriverIdsSprint == null) return;

        for (int i = 0; i < orderedDriverIdsSprint.size(); i++) {
            Long driverId = orderedDriverIdsSprint.get(i);
            int position = i + 1;

            int pts = sprintPointsSystem.pointsForPosition(position);

            state.addDriverPoints(driverId, pts);

            Long constructorId = driverToConstructor.get(driverId);
            if (constructorId != null) {
                state.addConstructorPoints(constructorId, pts);
            }
        }
    }

    public void applyRace(List<Long> orderedDriverIds) {
        if (orderedDriverIds == null) return;

        for (int i = 0; i < orderedDriverIds.size(); i++) {
            Long driverId = orderedDriverIds.get(i);
            int position = i + 1;

            int pts = pointsSystem.pointsForPosition(position);

            state.addDriverPoints(driverId, pts);

            Long constructorId = driverToConstructor.get(driverId);
            if (constructorId != null) {
                state.addConstructorPoints(constructorId, pts);
            }
        }
    }
}
