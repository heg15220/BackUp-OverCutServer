// src/modules/driverSeason/components/DriverSeasonGamePage.js
import React, { useEffect, useState } from "react";
import { useDispatch, useSelector } from "react-redux";
import { useNavigate } from "react-router-dom";

import * as actions from "../actions";
import { getDriverSeasonGame } from "../selectors";

import LoadingScreen from "../../common/components/LoadingScreen";
import MinigameTutorial from "../../common/components/MinigameTutorial";
import CooldownScreen from "../../cooldown/components/CooldownScreen";
import { fetchCooldown } from "../../cooldown/actions";
import { getCooldownForGame } from "../../cooldown/selectors";

import { tutorialTexts } from "../../../helpers/minigameTutorialTexts";
import { sourceImages } from "../../../helpers/sourceMiniGamesImages";

import DriverSeasonGameBoard from "./DriverSeasonGameBoard";
import "./DriverSeasonGame.css";

const getLang = () => (navigator.language?.startsWith("es") ? "es" : "en");

const GAME_KEY = "DriverSeasonGame";

const DriverSeasonGamePage = () => {
  const dispatch = useDispatch();
  const navigate = useNavigate();

  const lang = getLang();
  const [showTutorial, setShowTutorial] = useState(true);
  const [starting, setStarting] = useState(false); // evita dobles starts locales

  const game = useSelector(getDriverSeasonGame);

  const { canPlay, secondsRemaining, loading } = useSelector((state) =>
    getCooldownForGame(state, GAME_KEY)
  );

  const tutorial = tutorialTexts["/minigames/driverSeason"]?.[lang] || {
    title: lang === "es" ? "Driver Season" : "Driver Season",
    description:
      lang === "es"
        ? "Adivina la posición final del piloto en cada Gran Premio de esa temporada."
        : "Guess the driver’s finishing position for each race of that season."
  };

  // ✅ Cooldown: solo al montar (y el WAIT lo gestiona actions.js)
  useEffect(() => {
    dispatch(fetchCooldown(GAME_KEY));
  }, [dispatch]);

  // ✅ Arreglo simple y robusto: NO hacer fetchCooldown previo aquí
  const startNewGame = () => {
    if (starting) return;
    setStarting(true);

    dispatch(actions.clearDriverSeason());

    dispatch(
      actions.startDriverSeasonGame(
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

  // Si no puede jugar, mostramos cooldown (el estado lo trae fetchCooldown del mount
  // y se refresca si el backend devuelve WAIT gracias a actions.js)
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
        image={sourceImages(`./DriverSeason.png`)}
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
    <div className="driver-season-page">
      <DriverSeasonGameBoard onNewGame={handleNewGame} />
    </div>
  );
};

export default DriverSeasonGamePage;
