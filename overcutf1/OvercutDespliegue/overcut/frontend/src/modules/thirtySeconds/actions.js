import backend from "../../backend";
import * as actionTypes from "./actionTypes";
import { getUser } from "../users/selectors";

export const startThirtySecondsGame = () => (dispatch, getState) => {
  const user = getUser(getState());
  const lang = navigator.language.startsWith("es") ? "es" : "en";

  backend.thirtySecondsService.startGame(
    lang,
    user,
    (game) => dispatch({ type: actionTypes.START_30S_GAME_COMPLETED, game }),
    (err) => console.error("30s start error", err)
  );
};

export const submitThirtySeconds = (request) => (dispatch, getState) => {
  const user = getUser(getState());

  backend.thirtySecondsService.submit(
    request,
    user,
    (game) => dispatch({ type: actionTypes.SUBMIT_30S_GAME_COMPLETED, game }),
    (err) => console.error("30s submit error", err)
  );
};

export const fetchDriverSuggestions = (partial) => (dispatch, getState) => {
  const user = getUser(getState());

  backend.thirtySecondsService.autocompletePilotNames(
    partial,
    user,
    (suggestions) =>
      dispatch({ type: actionTypes.GET_30S_SUGGESTIONS_COMPLETED, suggestions }),
    (err) => {
      console.error("30s autocomplete error", err);
      dispatch({ type: actionTypes.GET_30S_SUGGESTIONS_COMPLETED, suggestions: [] });
    }
  );
};

export const clearDriverSuggestions = () => ({
  type: actionTypes.CLEAR_30S_SUGGESTIONS,
});
