package com.overcut.f1hub.rest.dtos;

import com.fasterxml.jackson.annotation.JsonProperty;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.List;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class ChartDataDTO {

    private String title;

    // ✅ En Java sigue siendo "type", pero en el JSON saldrá como "chartType"
    @JsonProperty("chartType")
    private String type; // "bar", "line", "pie", "scatter"

    private List<String> labels;

    private List<ChartSeriesDTO> datasets;
}
