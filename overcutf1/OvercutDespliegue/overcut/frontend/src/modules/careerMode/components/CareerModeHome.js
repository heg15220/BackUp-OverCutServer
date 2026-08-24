/**
 * The door to Career Mode.
 *
 * There are now two ways to race a whole Formula 1 career, and they differ in
 * one thing: how much of it you play by hand. The deep mode gives you every
 * Grand Prix; the quick one gives you every season. So the choice is presented
 * as exactly that difference - one card shows a single race's worth of laps,
 * the other a stack of seasons - rather than as two names you would have to
 * take on trust.
 *
 * The shell wears the OverCut seam because it belongs to neither mode: each
 * card previews its own palette instead, so you can see where you are going.
 *
 * Open to anyone. This screen is not part of OverCutGames and asks for no
 * account, which is why it links home rather than to the minigames hub.
 */

import React from "react";
import { Link } from "react-router-dom";
import "./CareerModeHome.css";

const detectLocale = () => {
  if (typeof navigator === "undefined") return "en";
  const lang = (navigator.language || navigator.userLanguage || "en").toLowerCase();
  return lang.startsWith("es") ? "es" : "en";
};

const STRINGS = {
  es: {
    back: "Volver a OverCut",
    kicker: "OverCut",
    title: "Modo Carrera",
    lead: "Dos formas de correr una carrera entera en la Fórmula 1. La diferencia es cuánto juegas tú.",
    deep: {
      name: "Carrera profunda",
      tag: "Juegas cada Gran Premio",
      copy: "Vives la temporada carrera a carrera, con narración en directo, condiciones de pista e incidentes. Firmas contratos, peleas con tu compañero y ves crecer tu carta de piloto.",
      points: [
        "Cada Gran Premio se simula y se cuenta",
        "Contratos, objetivos y duelo con tu compañero",
        "Guardas la partida con un código de exportación",
      ],
      cta: "Empezar carrera profunda",
    },
    quick: {
      name: "Simulación rápida",
      tag: "Juegas cada temporada",
      copy: "Una carrera completa desde 1950 hasta hoy. Las carreras se corren por dentro y tú decides entre temporadas: mercado, negociación, pretemporada y lo que pasa fuera de la pista.",
      points: [
        "Debuta en cualquier año desde 1950",
        "Una temporada por pantalla, no una carrera",
        "Palmarés, récords históricos y un rival de por vida",
      ],
      cta: "Empezar simulación rápida",
    },
    free: "Las dos se juegan sin cuenta.",
  },
  en: {
    back: "Back to OverCut",
    kicker: "OverCut",
    title: "Career Mode",
    lead: "Two ways to race a whole Formula 1 career. What changes is how much of it you play.",
    deep: {
      name: "Deep career",
      tag: "You play every Grand Prix",
      copy: "You live the season race by race, with live narration, track conditions and incidents. You sign contracts, fight your team-mate and watch your driver card grow.",
      points: [
        "Every Grand Prix is simulated and narrated",
        "Contracts, objectives and the team-mate duel",
        "Save your game with an export code",
      ],
      cta: "Start deep career",
    },
    quick: {
      name: "Quick simulation",
      tag: "You play every season",
      copy: "A whole career from 1950 to today. The races are run internally and you decide between seasons: the market, negotiation, preseason and what happens off track.",
      points: [
        "Debut in any year from 1950",
        "One season per screen, not one race",
        "Career record, all-time books and a lifelong rival",
      ],
      cta: "Start quick simulation",
    },
    free: "Both play without an account.",
  },
};

const t = STRINGS[detectLocale()] || STRINGS.en;

/* A single race, in laps: the grain the deep mode is played at. */
const LAPS = Array.from({ length: 30 }, (_, i) => i);

/* A run of seasons, each a row of Grands Prix: the grain of the quick one. */
const SEASONS = [
  "...p..p.P.pP..",
  "..p.Pp.P.pPW.p",
  ".pP.WpP.PW.pPW",
  "pPW.WPW.WpPWPW",
];

const Card = ({ to, mode, tone, children }) => (
  <article className={`cmh-card cmh-card--${tone}`}>
    <span className="cmh-card__swatch" aria-hidden="true" />
    <div className="cmh-card__head">
      <h2 className="cmh-card__name">{mode.name}</h2>
      <p className="cmh-card__tag">{mode.tag}</p>
    </div>

    <div className="cmh-card__token" aria-hidden="true">
      {children}
    </div>

    <p className="cmh-card__copy">{mode.copy}</p>

    <ul className="cmh-card__points">
      {mode.points.map((point) => (
        <li key={point}>{point}</li>
      ))}
    </ul>

    <Link className="cmh-cta" to={to}>
      {mode.cta}
    </Link>
  </article>
);

export const CareerModeHome = () => (
  <main className="cmh-root">
    <div className="cmh-cut" aria-hidden="true" />

    <div className="cmh-shell">
      <Link className="cmh-back" to="/">
        {t.back}
      </Link>

      <header className="cmh-head">
        <span className="cmh-kicker">{t.kicker}</span>
        <h1 className="cmh-title">{t.title}</h1>
        <p className="cmh-lead">{t.lead}</p>
      </header>

      <div className="cmh-cards">
        <Card to="/careerMode/deep" mode={t.deep} tone="deep">
          {/* One race, lap by lap. */}
          <span className="cmh-laps">
            {LAPS.map((lap) => (
              <i key={lap} className={lap === 22 ? "is-now" : undefined} />
            ))}
          </span>
        </Card>

        <Card to="/careerMode/trayectoria" mode={t.quick} tone="quick">
          {/* Season on season, each one a row of results. */}
          <span className="cmh-seasons">
            {SEASONS.map((season, row) => (
              <span key={season} className="cmh-seasons__row">
                {[...season].map((cell, index) => (
                  <i key={`${row}-${index}`} className={`is-${cell === "." ? "none" : cell}`} />
                ))}
              </span>
            ))}
          </span>
        </Card>
      </div>

      <p className="cmh-free">{t.free}</p>
    </div>
  </main>
);

export default CareerModeHome;
