// frontend/src/backend/towerService.js
import { fetchConfig, appFetch } from "./appFetch";

export const themes = (onSuccess, onErrors) =>
  appFetch(`/tower/themes`, fetchConfig("GET"), onSuccess, onErrors);

export const startGame = (lang, themeType, themeKey, user, onSuccess, onErrors) => {
  const qs = new URLSearchParams();
  qs.set("lang", lang);
  if (themeType) qs.set("themeType", themeType);
  if (themeKey) qs.set("themeKey", themeKey);

  // ✅ POST sin body -> null, user en 3er parámetro
  return appFetch(
    `/tower/start?${qs.toString()}`,
    fetchConfig("POST", null, user),
    onSuccess,
    onErrors
  );
};

export const guess = (request, user, onSuccess, onErrors) =>
  appFetch("/tower/guess", fetchConfig("POST", request, user), onSuccess, onErrors);

export const hint = (gameId, user, onSuccess, onErrors) =>
  // ✅ POST sin body -> null, user en 3er parámetro
  appFetch(`/tower/hint/${gameId}`, fetchConfig("POST", null, user), onSuccess, onErrors);

export const status = (gameId, user, onSuccess, onErrors) =>
  // ✅ GET: body null, user en 3er parámetro
  appFetch(`/tower/status/${gameId}`, fetchConfig("GET", null, user), onSuccess, onErrors);

export const autocomplete = (gameId, q, user, onSuccess, onErrors) =>
  // ✅ GET: body null, user en 3er parámetro
  appFetch(
    `/tower/${gameId}/autocomplete?q=${encodeURIComponent(q)}`,
    fetchConfig("GET", null, user),
    onSuccess,
    onErrors
  );

export const answer = (request, user, onSuccess, onErrors) =>
  appFetch("/tower/answer", fetchConfig("POST", request, user), onSuccess, onErrors);
