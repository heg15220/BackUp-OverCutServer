import backend from "../../backend";
import * as actionTypes from "./actionTypes";
import { getUser } from "../users/selectors";

export const startDriverStatsGame = () => (dispatch, getState) => {
  const lang = navigator.language.startsWith("es") ? "es" : "en";
  const user = getUser(getState());

  backend.driverStatsService.startGame(
    lang,
    user,
    (game) => dispatch({ type: actionTypes.START_DRIVER_STATS_GAME_COMPLETED, game }),
    (err) => console.error("DriverStats start error", err)
  );
};

export const submitDriverStats = (request) => (dispatch, getState) => {
  const user = getUser(getState());

  backend.driverStatsService.submit(
    request,
    user,
    (game) => dispatch({ type: actionTypes.SUBMIT_DRIVER_STATS_GAME_COMPLETED, game }),
    (err) => console.error("DriverStats submit error", err)
  );
};

export const getDriverStatsStatus = (gameId) => (dispatch, getState) => {
  const user = getUser(getState());

  backend.driverStatsService.getStatus(
    gameId,
    user,
    (game) => dispatch({ type: actionTypes.START_DRIVER_STATS_GAME_COMPLETED, game }),
    (err) => console.error("DriverStats status error", err)
  );
};
