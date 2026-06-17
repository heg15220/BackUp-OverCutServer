package com.overcut.predictions.model.dto;

import java.util.List;

public class CustomSprintDTO {
    private Integer round;
    private List<Long> orderedDriverIds; // clasificación final del sprint


    public Integer getRound() {
        return round;
    }

    public void setRound(Integer round) {
        this.round = round;
    }

    public List<Long> getOrderedDriverIds() {
        return orderedDriverIds;
    }

    public void setOrderedDriverIds(List<Long> orderedDriverIds) {
        this.orderedDriverIds = orderedDriverIds;
    }
}

