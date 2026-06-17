import { fetchConfig, appFetch } from "./appFetch";

export const startGame = (lang, user, onSuccess, onErrors) =>
  appFetch(
    `/thirtySecondsGame/start?lang=${encodeURIComponent(lang)}`,
    fetchConfig("POST", null, user),
    onSuccess,
    onErrors
  );

export const submit = (request, user, onSuccess, onErrors) =>
  appFetch(
    "/thirtySecondsGame/submit",
    fetchConfig("POST", request, user),
    onSuccess,
    onErrors
  );

export const getStatus = (gameId, user, onSuccess, onErrors) =>
  appFetch(
    `/thirtySecondsGame/status/${gameId}`,
    fetchConfig("GET", null, user),
    onSuccess,
    onErrors
  );

export const autocompletePilotNames = (partial, user, onSuccess, onErrors) =>
  appFetch(
    `/thirtySecondsGame/autocomplete?partial=${encodeURIComponent(partial)}`,
    fetchConfig("GET", null, user),
    onSuccess,
    onErrors
  );
