package com.overcut.f1hub.config;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.event.EventListener;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;
import org.springframework.boot.context.event.ApplicationReadyEvent;

import java.util.List;

@Component
public class QualiGapPrecomputeOnStartup {

    private final JdbcTemplate jdbc;

    // Puedes ajustar por properties:
    // f1hub.qualiGap.precompute.enabled=true
    // f1hub.qualiGap.precompute.fromYear=2003
    // f1hub.qualiGap.precompute.lastNYears=0   (0 = todos)
    @Value("${f1hub.qualiGap.precompute.enabled:true}")
    private boolean enabled;

    @Value("${f1hub.qualiGap.precompute.fromYear:2003}")
    private int fromYear;

    @Value("${f1hub.qualiGap.precompute.lastNYears:0}")
    private int lastNYears;

    public QualiGapPrecomputeOnStartup(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    @EventListener(ApplicationReadyEvent.class)
    public void precompute() {
        if (!enabled) return;

        Integer maxYear = jdbc.queryForObject("SELECT MAX(year) FROM races", Integer.class);
        if (maxYear == null) return;

        int start = Math.max(fromYear, 1950);
        int end = maxYear;

        if (lastNYears > 0) {
            start = Math.max(start, end - lastNYears + 1);
        }

        // Años presentes en races (evita años vacíos)
        List<Integer> years = jdbc.queryForList(
                "SELECT DISTINCT year FROM races WHERE year BETWEEN ? AND ? ORDER BY year",
                Integer.class,
                start, end
        );

        for (Integer year : years) {
            if (year == null) continue;
            if (year < fromYear) continue;

            boolean hasRows = hasTeamQualiGapRowsForYear(year);
            if (!hasRows) {
                // Esto rellena: qualifying_best_ms, quali_pole_ms, team_quali_gap_per_race
                jdbc.execute("CALL refresh_quali_gap_tables(" + year + ")");
            }
        }
    }

    private boolean hasTeamQualiGapRowsForYear(int year) {
        Integer cnt = jdbc.queryForObject("""
            SELECT COUNT(*)
            FROM team_quali_gap_per_race tqg
            JOIN races r ON r.raceId = tqg.raceId
            WHERE r.year = ?
        """, Integer.class, year);

        return cnt != null && cnt > 0;
    }
}
