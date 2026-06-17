import { fetchConfig, appFetch } from "./appFetch";

export const startGame = (lang, user, onSuccess, onErrors) =>
  appFetch(
    `/teamNationalityGame/start?lang=${encodeURIComponent(lang)}`,
    fetchConfig("POST", null, user),
    onSuccess,
    onErrors
  );

export const guess = (request, user, onSuccess, onErrors) =>
  appFetch(
    "/teamNationalityGame/guess",
    fetchConfig("POST", request, user),
    onSuccess,
    onErrors
  );

export const getStatus = (gameId, user, onSuccess, onErrors) =>
  appFetch(
    `/teamNationalityGame/status/${gameId}`,
    fetchConfig("GET", null, user),
    onSuccess,
    onErrors
  );

export const autocompletePilotNames = (partial, user, onSuccess, onErrors) =>
  appFetch(
    `/teamNationalityGame/autocomplete?partial=${encodeURIComponent(partial)}`,
    fetchConfig("GET", null, user),
    onSuccess,
    onErrors
  );
