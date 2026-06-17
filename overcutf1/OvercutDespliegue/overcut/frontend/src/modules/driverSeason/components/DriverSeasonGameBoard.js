// src/modules/driverSeason/components/DriverSeasonGameBoard.js
import React from "react";
import { useDispatch, useSelector } from "react-redux";
import { useNavigate } from "react-router-dom";

import {
  getDriverSeasonGame,
  getDriverSeasonRounds,
  getDriverSeasonMaxPosition,
  getDriverSeasonCompleted,
  getDriverSeasonRevealed
} from "../selectors";

import * as actions from "../actions";
import DriverSeasonRoundSlot from "./DriverSeasonRoundSlot";

import "./DriverSeasonGame.css";
import LoadingScreen from "../../common/components/LoadingScreen";

const DriverSeasonGameBoard = ({ onNewGame }) => {
  const dispatch = useDispatch();
  const navigate = useNavigate();

  const lang = navigator.language.startsWith("es") ? "es" : "en";
  const t = {
    title: lang === "es" ? "Temporada Piloto" : "Driver Season",
    subtitle: lang === "es" ? "Temporada" : "Season",
    reveal: lang === "es" ? "Rendirse" : "Give up",
    loading: lang === "es" ? "Cargando..." : "Loading...",
    newGame: lang === "es" ? "Nueva partida" : "New game"
  };

  const game = useSelector(getDriverSeasonGame);
  const rounds = useSelector(getDriverSeasonRounds);
  const maxPos = useSelector(getDriverSeasonMaxPosition);
  const completed = useSelector(getDriverSeasonCompleted);
  const revealed = useSelector(getDriverSeasonRevealed);

  if (!game) return <LoadingScreen lang={lang} text={t.loading} />;

  const driverLabel = game?.driverName ? ` — ${game.driverName}` : "";

  const handleReveal = () => {
    dispatch(
      actions.revealDriverSeasonGame(
        game.gameId,
        () => {
          dispatch(actions.clearDriverSeason());
          navigate("/minigames");
        },
        () => {
          dispatch(actions.clearDriverSeason());
          navigate("/minigames");
        }
      )
    );
  };

  return (
    <div className="driver-season-container">
      <h2 className="driver-season-title">
        <span className="driver-season-title-main">
          {t.title}
          {driverLabel}
        </span>
        <span className="driver-season-title-sub">
          {t.subtitle}: {game.seasonYear}
        </span>
      </h2>

      {/* Acciones */}
      {!completed && !revealed && (
        <div className="driver-season-actions">
          <button
            className="driver-season-reveal"
            onClick={handleReveal}
            title={t.reveal}
            type="button"
          >
            {t.reveal}
          </button>

          {/* ✅ Nueva partida (si te lo pasan desde Page) */}
        </div>
      )}

      {/* Al terminar o rendirse: volver a minijuegos */}
      {(completed || revealed) && (
        <button
          className="driver-season-back-minigames"
          type="button"
          onClick={() => {
            dispatch(actions.clearDriverSeason());
            navigate("/minigames");
          }}
        >
          {lang === "es" ? "Volver a inicio" : "Back home"}
        </button>
      )}

      <div className="driver-season-grid">
        {rounds.map((r) => (
          <DriverSeasonRoundSlot
            key={r.raceId}
            gameId={game.gameId}
            round={r}
            lang={lang}
            maxPosition={maxPos}
            disabled={completed || revealed || r.isCorrect != null}
          />
        ))}
      </div>
    </div>
  );
};

export default DriverSeasonGameBoard;
