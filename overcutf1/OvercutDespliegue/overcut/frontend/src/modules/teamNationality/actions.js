import backend from "../../backend";
import * as actionTypes from "./actionTypes";
import { getUser } from "../users/selectors";

export const startTeamNationalityGame = () => (dispatch, getState) => {
  const user = getUser(getState());
  const lang = navigator.language.startsWith("es") ? "es" : "en";

  backend.teamNationalityService.startGame(
    lang,
    user,
    (game) => dispatch({ type: actionTypes.START_TEAMNAT_GAME_COMPLETED, game }),
    (err) => console.error("TeamNationality start error", err)
  );
};

export const guessTeamNationality = (request) => (dispatch, getState) => {
  const user = getUser(getState());

  backend.teamNationalityService.guess(
    request,
    user,
    (game) => dispatch({ type: actionTypes.GUESS_TEAMNAT_COMPLETED, game }),
    (err) => console.error("TeamNationality guess error", err)
  );
};

export const fetchTeamNatSuggestions = (partial) => (dispatch, getState) => {
  const user = getUser(getState());

  backend.teamNationalityService.autocompletePilotNames(
    partial,
    user,
    (suggestions) =>
      dispatch({ type: actionTypes.GET_TEAMNAT_SUGGESTIONS_COMPLETED, suggestions }),
    (err) => console.error("TeamNationality autocomplete error", err)
  );
};

export const clearTeamNatSuggestions = () => ({ type: actionTypes.CLEAR_TEAMNAT_SUGGESTIONS });
