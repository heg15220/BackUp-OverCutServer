import React, { useEffect } from "react";
import { useDispatch, useSelector } from "react-redux";
import * as actions from "../actions";
import * as selectors from "../selectors";
import "./RankingPage.css";
import UserAvatar from "./UserAvatar";

const rankThresholds = {
  ELITE: 3000,
  F1: 1000,
  F2: 500,
  F3: 150,
  F4: 0
};

// Mantén el orden visual (top → bottom)
const rankOrder = ["ELITE", "F1", "F2", "F3", "F4"];

const translations = {
  es: {
    title: "🏁 Ranking Global",
    legendTitle: "Leyenda de Rangos",
    empty: "🚧 No hay usuarios en este rango.",
    goal: (points) => `🎯 Objetivo: ${points} puntos.`,
  },
  en: {
    title: "🏁 Global Ranking",
    legendTitle: "Rank Legend",
    empty: "🚧 No users in this rank yet.",
    goal: (points) => `🎯 Goal: ${points} points.`,
  }
};

// Etiquetas a mostrar para cada rango (localizadas)
const rankLabels = {
  es: {
    ELITE: "Élite",
    F1: "Oro",
    F2: "Plata",
    F3: "Bronce",
    F4: "Rookie",
  },
  en: {
    ELITE: "Elite",
    F1: "Gold",
    F2: "Silver",
    F3: "Bronze",
    F4: "Rookie",
  }
};

// Descripciones cortas opcionales
const rankDescriptions = {
  es: {
    ELITE: "Maestro de OverCut",
    F1: "Legendario",
    F2: "Profesional",
    F3: "Competidor",
    F4: "Novato",
  },
  en: {
    ELITE: "OverCut Master",
    F1: "Legendary",
    F2: "Professional",
    F3: "Competitive",
    F4: "Rookie",
  }
};

const RankingPage = () => {
  const dispatch = useDispatch();
  const ranking = useSelector(selectors.getUserRanking);
  const locale = navigator.language.startsWith("es") ? "es" : "en";
  const t = translations[locale];
  const labels = rankLabels[locale];
  const desc = rankDescriptions[locale];

  useEffect(() => {
    dispatch(actions.getUserRanking());
  }, [dispatch]);

  return (
    <div className="ranking-wrapper">
      <h2 className="ranking-header">{t.title}</h2>

      <div className="ranking-legend">
        <h3>{t.legendTitle}</h3>
        <div className="legend-items">
          {rankOrder.map(rank => (
            <div key={rank} className={`legend-item legend-${rank.toLowerCase()}`}>
              <span className="legend-color"></span>
              <span className="legend-label">
                {labels[rank]}
                {/*  — {desc[rank]}  */}
              </span>
            </div>
          ))}
        </div>
      </div>

      {rankOrder.map(rank => {
        const users = [...(ranking[rank] || [])].sort((a, b) => b.points - a.points);

        return (
          <div key={rank} className="ranking-rank-section">
            <h3 className={`rank-header rank-${rank.toLowerCase()}`}>
              {labels[rank]}
            </h3>

            {users.length > 0 ? (
              <div className="ranking-list">
                {users.map((user, idx) => (
                  <div key={idx} className={`ranking-row rank-${rank.toLowerCase()}`}>
                    <div className="ranking-pos">#{idx + 1}</div>
                    <UserAvatar image={user.image} userName={user.userName} size={40} />
                    <div className="ranking-name">{user.userName}</div>
                    <div className="ranking-points">{user.points} pts</div>
                  </div>
                ))}
              </div>
            ) : (
              <div className="ranking-empty">{t.empty}</div>
            )}

            <p className="ranking-goal">{t.goal(rankThresholds[rank])}</p>
          </div>
        );
      })}
    </div>
  );
};

export default RankingPage;
