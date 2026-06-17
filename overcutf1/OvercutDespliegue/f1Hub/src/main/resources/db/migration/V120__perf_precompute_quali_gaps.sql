DROP TABLE IF EXISTS qualifying_best_ms;
CREATE TABLE qualifying_best_ms (
  raceId BIGINT NOT NULL,
  driverId BIGINT NOT NULL,
  constructorId BIGINT NOT NULL,
  bestMs INT NOT NULL,
  PRIMARY KEY (raceId, driverId),
  INDEX idx_qbm_race_constructor (raceId, constructorId),
  INDEX idx_qbm_constructor (constructorId)
) ENGINE=InnoDB;

DROP TABLE IF EXISTS quali_pole_ms;
CREATE TABLE quali_pole_ms (
  raceId BIGINT NOT NULL PRIMARY KEY,
  poleMs INT NOT NULL,
  INDEX idx_qpm_pole (poleMs)
) ENGINE=InnoDB;

DROP TABLE IF EXISTS team_quali_gap_per_race;
CREATE TABLE team_quali_gap_per_race (
  raceId BIGINT NOT NULL,
  constructorId BIGINT NOT NULL,
  avgQualiGapMs DOUBLE NOT NULL,
  PRIMARY KEY (raceId, constructorId),
  INDEX idx_tqg_race (raceId),
  INDEX idx_tqg_constructor (constructorId)
) ENGINE=InnoDB;

ANALYZE TABLE qualifying_best_ms;
ANALYZE TABLE quali_pole_ms;
ANALYZE TABLE team_quali_gap_per_race;
