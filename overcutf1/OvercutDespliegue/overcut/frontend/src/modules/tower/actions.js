// frontend/src/modules/tower/actions.js
import backend from "../../backend";
import * as actionTypes from "./actionTypes";
import { getUser } from "../users/selectors";

// 1) cargar catálogo de temas (para desplegables)
export const loadTowerThemes = () => (dispatch) => {
  backend.towerService.themes(
    (data) => dispatch({ type: actionTypes.TOWER_THEMES_COMPLETED, themes: data }),
    (err) => console.error("Tower themes error", err)
  );
};

// 2) arrancar partida (random o forzada)
export const startTowerGame = (themeType = null, themeKey = null) => (dispatch, getState) => {
  const lang = navigator.language.startsWith("es") ? "es" : "en";
  const user = getUser(getState());

  backend.towerService.startGame(
    lang,
    themeType,
    themeKey,
    user,
    (game) => dispatch({ type: actionTypes.TOWER_START_COMPLETED, game }),
    (err) => console.error("Tower start error", err)
  );
};

export const guessTower = (gameId, driverId, driverName) => (dispatch, getState) => {
  const user = getUser(getState());

  backend.towerService.guess(
    { gameId, driverId, driverName },
    user,
    (game) => dispatch({ type: actionTypes.TOWER_GUESS_COMPLETED, game }),
    (err) => console.error("Tower guess error", err)
  );
};

export const requestTowerHint = (gameId) => (dispatch, getState) => {
  const user = getUser(getState());
  backend.towerService.hint(gameId, user, (hint) =>
    dispatch({ type: actionTypes.TOWER_HINT_COMPLETED, hint })
  );
};

export const getTowerStatus = (gameId) => (dispatch, getState) => {
  const user = getUser(getState());
  backend.towerService.status(gameId, user, (game) =>
    dispatch({ type: actionTypes.TOWER_STATUS_COMPLETED, game })
  );
};

export const clearTower = () => ({ type: actionTypes.TOWER_CLEAR });

export const answerTower = (gameId, themeType, themeKey) => (dispatch, getState) => {
  const user = getUser(getState());

  backend.towerService.answer(
    { gameId, themeType, themeKey },
    user,
    (game) => dispatch({ type: actionTypes.TOWER_ANSWER_COMPLETED, game }),
    (err) => console.error("Tower answer error", err)
  );
};
