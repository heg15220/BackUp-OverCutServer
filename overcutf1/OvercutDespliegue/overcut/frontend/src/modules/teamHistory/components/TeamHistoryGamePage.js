// src/modules/teamHistory/components/TeamHistoryGamePage.js
import React, { useEffect, useState } from "react";
import { useDispatch, useSelector } from "react-redux";
import { useNavigate } from "react-router-dom";

import * as actions from "../actions";
import { getTeamHistoryGame } from "../selectors";

import LoadingScreen from "../../common/components/LoadingScreen";
import MinigameTutorial from "../../common/components/MinigameTutorial";
import CooldownScreen from "../../cooldown/components/CooldownScreen";
import { fetchCooldown } from "../../cooldown/actions";
import { getCooldownForGame } from "../../cooldown/selectors";

import { tutorialTexts } from "../../../helpers/minigameTutorialTexts";
import { sourceImages } from "../../../helpers/sourceMiniGamesImages";

import TeamHistoryGameBoard from "./TeamHistoryGameBoard";
import "./TeamHistoryGame.css";

const getLang = () => (navigator.language?.startsWith("es") ? "es" : "en");

const GAME_KEY = "TeamHistoryGame";

export default function TeamHistoryGamePage() {
  const dispatch = useDispatch();
  const navigate = useNavigate();
  const lang = getLang();

  const [showTutorial, setShowTutorial] = useState(true);
  const [starting, setStarting] = useState(false); // evita dobles starts locales
  const game = useSelector(getTeamHistoryGame);

  const { canPlay, secondsRemaining, loading } = useSelector((state) =>
    getCooldownForGame(state, GAME_KEY)
  );

  const tutorial = tutorialTexts["/minigames/teamHistory"]?.[lang] || {
    title: lang === "es" ? "Historia de Equipo" : "Team History",
    description:
      lang === "es"
        ? "Adivina la posición final del equipo en el campeonato de constructores para cada temporada."
        : "Guess the team’s final Constructors’ Championship position for each season."
  };

  // ✅ Cooldown: solo al montar (y el WAIT lo gestiona actions.js)
  useEffect(() => {
    dispatch(fetchCooldown(GAME_KEY));
  }, [dispatch]);

  // ✅ Arreglo simple y robusto: NO hacer fetchCooldown previo aquí
  const startNewGame = () => {
    if (starting) return;
    setStarting(true);

    dispatch(actions.clearTeamHistory());

    dispatch(
      actions.startTeamHistoryGame(
        lang,
        () => setStarting(false),
        () => setStarting(false)
      )
    );
  };

  const handleNewGame = () => startNewGame();

  if (loading) {
    return (
      <LoadingScreen
        lang={lang}
        text={lang === "es" ? "Cargando..." : "Loading..."}
      />
    );
  }

  if (!canPlay) {
    return (
      <CooldownScreen
        seconds={secondsRemaining}
        onBack={() => navigate("/minigames")}
      />
    );
  }

  if (showTutorial) {
    return (
      <MinigameTutorial
        title={tutorial.title}
        description={tutorial.description}
        image={sourceImages(`./TeamHistory.png`)}
        onStart={() => {
          setShowTutorial(false);
          startNewGame();
        }}
        lang={lang}
      />
    );
  }

  if (!game) {
    return (
      <LoadingScreen
        lang={lang}
        text={lang === "es" ? "Cargando juego..." : "Loading game..."}
      />
    );
  }

  return (
    <div className="team-history-page">
      <TeamHistoryGameBoard onNewGame={handleNewGame} />
    </div>
  );
}
