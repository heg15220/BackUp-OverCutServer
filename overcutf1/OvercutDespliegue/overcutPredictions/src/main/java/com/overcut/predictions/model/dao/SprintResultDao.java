package com.overcut.predictions.model.dao;

import com.overcut.predictions.model.entities.SprintResult;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;

public interface SprintResultDao extends JpaRepository<SprintResult, Long> {

    List<SprintResult> findByRaceId(Long raceId);

    /**
     * ✅ Devuelve las rondas (round) que tienen sprint en una season.
     * Se apoya en la relación por raceId entre sprintresults y races.
     */
    @Query("""
        select distinct r.round
        from SprintResult sr, Race r
        where sr.raceId = r.raceId
          and r.year = :season
        order by r.round
    """)
    List<Integer> findSprintRoundsBySeason(@Param("season") Integer season);
}
