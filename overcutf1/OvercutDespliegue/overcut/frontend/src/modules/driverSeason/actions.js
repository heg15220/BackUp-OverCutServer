// src/modules/driverSeason/actions.js
import backend from "../../backend";
import * as actionTypes from "./actionTypes";
import { fetchCooldown } from "../cooldown/actions"; // ✅ AJUSTA RUTA SI TU ESTRUCTURA ES OTRA

const GAME_KEY = "DriverSeasonGame";

const isWaitCooldownError = (e) => {
  // tolerante a distintos formatos
  if (!e) return false;

  const code =
    e.code ||
    e?.response?.data?.code ||
    e?.data?.code ||
    e?.payload?.code;

  const message =
    e.message ||
    e?.response?.data?.message ||
    e?.data?.message ||
    "";

  // backend típico: { code: "WAIT", secondsRemaining: ... }
  if (String(code).toUpperCase() === "WAIT") return true;

  // fallback
  return typeof message === "string" && message.toUpperCase().includes("WAIT");
};

export const startDriverSeasonGame = (lang, onSuccess, onErrors) => (dispatch) =>
  backend.driverSeasonService.startGame(
    lang,
    (game) => {
      dispatch({ type: actionTypes.DRIVER_SEASON_START_COMPLETED, game });
      onSuccess && onSuccess(game);
    },
    (err) => {
      // ✅ si el backend dice WAIT, refrescamos cooldown para que el UI muestre bien el timer
      if (isWaitCooldownError(err)) {
        dispatch(fetchCooldown(GAME_KEY));
      }
      onErrors && onErrors(err);
    }
  );

export const getDriverSeasonGame = (gameId, onSuccess, onErrors) => (dispatch) =>
  backend.driverSeasonService.getGame(
    gameId,
    (game) => {
      dispatch({ type: actionTypes.DRIVER_SEASON_GET_COMPLETED, game });
      onSuccess && onSuccess(game);
    },
    onErrors
  );

export const validateDriverSeasonGuess =
  (gameId, raceId, guessPosition, onSuccess, onErrors) => (dispatch) =>
    backend.driverSeasonService.validateGuess(
      { gameId, raceId, guessPosition },
      (res) => {
        dispatch({
          type: actionTypes.DRIVER_SEASON_VALIDATE_COMPLETED,
          gameId,
          raceId,
          guessPosition,
          res
        });
        onSuccess && onSuccess(res);
      },
      onErrors
    );

export const revealDriverSeasonGame =
  (gameId, onSuccess, onErrors) => (dispatch) =>
    backend.driverSeasonService.reveal(
      gameId,
      (game) => {
        dispatch({ type: actionTypes.DRIVER_SEASON_REVEAL_COMPLETED, game });
        onSuccess && onSuccess(game);
      },
      onErrors
    );

export const clearDriverSeason = () => ({
  type: actionTypes.DRIVER_SEASON_CLEAR
});
