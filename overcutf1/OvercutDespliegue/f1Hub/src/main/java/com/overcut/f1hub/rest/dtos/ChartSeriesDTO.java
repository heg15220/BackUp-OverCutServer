package com.overcut.f1hub.rest.dtos;

import lombok.AccessLevel;
import lombok.Data;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.util.List;

@Data
@NoArgsConstructor
public class ChartSeriesDTO {

    private String label;

    // Backward-compatible (un color)
    private String color;

    // ✅ Vamos a controlar el setter para mantener fallback a "color"
    @Setter(AccessLevel.NONE)
    private List<String> colors;

    private List<Double> data;

    private String abbreviation; // opcional

    // Constructor clásico (1 color)
    public ChartSeriesDTO(String label, String color, List<Double> data) {
        this.label = label;
        this.color = color;
        this.data = data;
    }

    // Constructor solo label + data
    public ChartSeriesDTO(String label, List<Double> data) {
        this.label = label;
        this.data = data;
    }

    // Constructor nuevo (lista de colores)
    public ChartSeriesDTO(String label, List<String> colors, List<Double> data) {
        this.label = label;
        this.data = data;
        setColors(colors); // ✅ reutiliza la lógica de fallback
    }

    // ✅ Setter custom para mantener compatibilidad con frontend:
    // si "color" no está definido, usa el primero de "colors"
    public void setColors(List<String> colors) {
        this.colors = colors;
        if ((this.color == null || this.color.isBlank())
                && colors != null && !colors.isEmpty()
                && colors.get(0) != null && !colors.get(0).isBlank()) {
            this.color = colors.get(0);
        }
    }
}
