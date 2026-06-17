import { appFetch, fetchConfig } from "./appFetch";

/**
 * Soporta:
 *  - bootstrapSeason(season, fromRound, onSuccess, onErrors)
 *  - bootstrapSeason(season, fromRound, pointsEra, onSuccess, onErrors)
 */
export const bootstrapSeason = (season, fromRound, a3, a4, a5) => {
  const hasPointsEra = typeof a3 === "number" || (typeof a3 === "string" && a3 !== "");
  const pointsEra = hasPointsEra ? a3 : null;

  const onSuccess = hasPointsEra ? a4 : a3;
  const onErrors = hasPointsEra ? a5 : a4;

  const pe =
    pointsEra != null && pointsEra !== ""
      ? `&pointsEra=${encodeURIComponent(pointsEra)}`
      : "";

  return appFetch(
    `/predictions/bootstrap?season=${encodeURIComponent(season)}&fromRound=${encodeURIComponent(fromRound)}${pe}`,
    fetchConfig("GET"),
    onSuccess,
    onErrors
  );
};

// ✅ NUEVO
export const bootstrapSeasonCustom = (payload, onSuccess, onErrors) =>
  appFetch(`/predictions/bootstrap-custom`, fetchConfig("POST", payload), onSuccess, onErrors);

export const applySimulation = (payload, onSuccess, onErrors) =>
  appFetch(`/predictions/simulate/apply`, fetchConfig("POST", payload), onSuccess, onErrors);

export const applySimulationBatch = (payload, onSuccess, onErrors) =>
  appFetch(`/predictions/simulate/apply-batch`, fetchConfig("POST", payload), onSuccess, onErrors);

