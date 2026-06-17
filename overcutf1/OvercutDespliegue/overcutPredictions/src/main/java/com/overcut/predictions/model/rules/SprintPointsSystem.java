package com.overcut.predictions.model.rules;

public class SprintPointsSystem {

    private final SprintPointsMode mode;

    public SprintPointsSystem(SprintPointsMode mode) {
        this.mode = (mode != null) ? mode : SprintPointsMode.TOP8_8_TO_1;
    }

    public int pointsForPosition(int pos) {
        if (pos <= 0) return 0;
        return switch (mode) {
            case TOP3_3_2_1 -> (pos == 1 ? 3 : (pos == 2 ? 2 : (pos == 3 ? 1 : 0)));
            case TOP8_8_TO_1 -> (pos <= 8 ? (9 - pos) : 0); // 1->8, 2->7, ..., 8->1
        };
    }

    public SprintPointsMode getMode() { return mode; }
}
