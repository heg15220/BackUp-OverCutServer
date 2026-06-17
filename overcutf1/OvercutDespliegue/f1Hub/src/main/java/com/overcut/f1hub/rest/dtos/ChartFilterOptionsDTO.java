package com.overcut.f1hub.rest.dtos;

import com.overcut.f1hub.model.service.AdvancedStatsService.CircuitOption;
import com.overcut.f1hub.model.service.AdvancedStatsService.ConstructorOption;
import com.overcut.f1hub.model.service.AdvancedStatsService.DriverOption;

import java.util.List;

public class ChartFilterOptionsDTO {

    public List<DriverOption> drivers;
    public List<ConstructorOption> constructors;
    public List<Integer> seasons;

    // ✅ IMPORTANTE: el frontend usa filters.circuitOptions
    public List<CircuitOption> circuitOptions;

    public ChartFilterOptionsDTO() {}

    public ChartFilterOptionsDTO(List<DriverOption> drivers,
                                 List<ConstructorOption> constructors,
                                 List<Integer> seasons,
                                 List<CircuitOption> circuitOptions) {
        this.drivers = drivers;
        this.constructors = constructors;
        this.seasons = seasons;
        this.circuitOptions = circuitOptions;
    }
}
