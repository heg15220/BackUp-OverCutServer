package com.overcut.predictions.model.entities;

import jakarta.persistence.*;

@Entity
@Table(name = "sprintresults")
public class SprintResult {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "sprintResultId")
    private Long sprintResultId;

    @Column(name = "raceId")
    private Long raceId;

    @Column(name = "driverId")
    private Long driverId;

    @Column(name = "constructorId")
    private Long constructorId;

    @Column(name = "positionOrder")
    private Integer positionOrder;

    @Column(name = "points")
    private Double points;

    public Long getSprintResultId() { return sprintResultId; }
    public Long getRaceId() { return raceId; }
    public Long getDriverId() { return driverId; }
    public Long getConstructorId() { return constructorId; }
    public Integer getPositionOrder() { return positionOrder; }
    public Double getPoints() { return points; }

    public void setSprintResultId(Long sprintResultId) { this.sprintResultId = sprintResultId; }
    public void setRaceId(Long raceId) { this.raceId = raceId; }
    public void setDriverId(Long driverId) { this.driverId = driverId; }
    public void setConstructorId(Long constructorId) { this.constructorId = constructorId; }
    public void setPositionOrder(Integer positionOrder) { this.positionOrder = positionOrder; }
    public void setPoints(Double points) { this.points = points; }
}
