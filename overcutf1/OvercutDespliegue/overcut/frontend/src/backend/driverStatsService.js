import { fetchConfig, appFetch } from "./appFetch";

export const startGame = (lang, user, onSuccess, onErrors) =>
  appFetch(
    `/driverStatsGame/start?lang=${encodeURIComponent(lang)}`,
    fetchConfig("POST", null, user),
    onSuccess,
    onErrors
  );

export const submit = (request, user, onSuccess, onErrors) =>
  appFetch(
    "/driverStatsGame/submit",
    fetchConfig("POST", request, user),
    onSuccess,
    onErrors
  );

export const getStatus = (gameId, user, onSuccess, onErrors) =>
  appFetch(
    `/driverStatsGame/status/${gameId}`,
    fetchConfig("GET", null, user),
    onSuccess,
    onErrors
  );
