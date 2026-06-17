package com.overcut.f1hub.config;

import org.flywaydb.core.api.callback.Callback;
import org.flywaydb.core.api.callback.Context;
import org.flywaydb.core.api.callback.Event;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import java.sql.SQLException;
import java.sql.Statement;

@Configuration
public class FlywayProceduresCallback {

    @Bean
    public Callback refreshQualiGapProcedureCallback() {
        return new Callback() {

            @Override
            public boolean supports(Event event, Context context) {
                return event == Event.AFTER_MIGRATE;
            }

            @Override
            public boolean canHandleInTransaction(Event event, Context context) {
                return false; // MySQL procedures -> no transaccional / no fiable
            }

            @Override
            public void handle(Event event, Context context) {
                try (Statement st = context.getConnection().createStatement()) {

                    // 1) DROP
                    st.execute("DROP PROCEDURE IF EXISTS refresh_quali_gap_tables");

                    // 2) CREATE como un único statement (sin DELIMITER)
                    String create =
                            "CREATE PROCEDURE refresh_quali_gap_tables(IN p_year INT) " +
                            "BEGIN " +

                            // --- Limpieza SOLO del año pedido ---
                            "  DELETE qbm FROM qualifying_best_ms qbm " +
                            "  JOIN races r ON r.raceId = qbm.raceId " +
                            "  WHERE r.year = p_year; " +

                            "  DELETE qpm FROM quali_pole_ms qpm " +
                            "  JOIN races r ON r.raceId = qpm.raceId " +
                            "  WHERE r.year = p_year; " +

                            "  DELETE tqg FROM team_quali_gap_per_race tqg " +
                            "  JOIN races r ON r.raceId = tqg.raceId " +
                            "  WHERE r.year = p_year; " +

                            // --- 1) Best qualifying ms por piloto/carrera/equipo (SOLO año pedido) ---
                            "  INSERT INTO qualifying_best_ms (raceId, driverId, constructorId, bestMs) " +
                            "  SELECT q.raceId, q.driverId, q.constructorId, " +
                            "    CAST(ROUND(1000 * LEAST( " +
                            "      CASE WHEN q.q1 REGEXP '^[0-9]+:[0-9]+\\\\.[0-9]+$' THEN TIME_TO_SEC(STR_TO_DATE(q.q1, '%i:%s.%f')) ELSE 999999 END, " +
                            "      CASE WHEN q.q2 REGEXP '^[0-9]+:[0-9]+\\\\.[0-9]+$' THEN TIME_TO_SEC(STR_TO_DATE(q.q2, '%i:%s.%f')) ELSE 999999 END, " +
                            "      CASE WHEN q.q3 REGEXP '^[0-9]+:[0-9]+\\\\.[0-9]+$' THEN TIME_TO_SEC(STR_TO_DATE(q.q3, '%i:%s.%f')) ELSE 999999 END " +
                            "    )) AS SIGNED) AS bestMs " +
                            "  FROM qualifying q " +
                            "  JOIN races r ON r.raceId = q.raceId " +
                            "  WHERE r.year = p_year AND q.position IS NOT NULL " +
                            "  HAVING bestMs < 999999000; " +

                            // --- 2) Pole ms por carrera (SOLO año pedido) ---
                            // FIX: filtrar por p_year (antes se metían poles de otros años si qualifying_best_ms tenía datos mezclados)
                            // + Idempotente: ON DUPLICATE KEY UPDATE
                            "  INSERT INTO quali_pole_ms (raceId, poleMs) " +
                            "  SELECT qbm.raceId, MIN(qbm.bestMs) " +
                            "  FROM qualifying_best_ms qbm " +
                            "  JOIN races r ON r.raceId = qbm.raceId " +
                            "  JOIN qualifying q ON q.raceId = qbm.raceId AND q.driverId = qbm.driverId " +
                            "  WHERE r.year = p_year " +
                            "    AND q.position = 1 " +
                            "  GROUP BY qbm.raceId " +
                            "  ON DUPLICATE KEY UPDATE poleMs = VALUES(poleMs); " +

                            // --- 3) Gap medio por equipo y carrera vs pole (SOLO año pedido) ---
                            // FIX: filtrar por p_year
                            // + Idempotente: ON DUPLICATE KEY UPDATE
                            "  INSERT INTO team_quali_gap_per_race (raceId, constructorId, avgQualiGapMs) " +
                            "  SELECT qbm.raceId, qbm.constructorId, AVG(qbm.bestMs - qpm.poleMs) " +
                            "  FROM qualifying_best_ms qbm " +
                            "  JOIN races r ON r.raceId = qbm.raceId " +
                            "  JOIN quali_pole_ms qpm ON qpm.raceId = qbm.raceId " +
                            "  WHERE r.year = p_year " +
                            "  GROUP BY qbm.raceId, qbm.constructorId " +
                            "  ON DUPLICATE KEY UPDATE avgQualiGapMs = VALUES(avgQualiGapMs); " +

                            "END";

                    st.execute(create);

                } catch (SQLException e) {
                    throw new RuntimeException("Failed to create procedure refresh_quali_gap_tables", e);
                }
            }

            @Override
            public String getCallbackName() {
                return "refreshQualiGapProcedureCallback";
            }
        };
    }
}
