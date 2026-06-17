  import React from "react";
  import { useSelector } from "react-redux";
  import { useNavigate } from "react-router-dom";
  import users from "../../users";
  import "./StartHome.css";
  import { getAboutOvercutImage } from "../../../helpers/sourceAboutOvercutImages";

  const StartHome = () => {
    const navigate = useNavigate();
    const isLogged = useSelector(users.selectors.isLoggedIn);
    const lang = navigator.language.startsWith("es") ? "es" : "en";

    const t = {
    es: {
      title: "Bienvenido a OverCut",
      subtitle: "Elige una sección para empezar",
      quiz: "Quiz",
      quizDesc: "Demuestra tu conocimiento F1",
      games: "OverCutGames",
      gamesDesc: "Minijuegos temáticos y retos",
      draft: "OverCutDraft",
      draftDesc: "Draftea equipos y pilotos históricos para jugar y simular campeonatos ficticios",
      careerMode: "OverCutCareer",
      careerModeDesc: "Crea tu propio piloto y disputa su carrera deportiva en búsqueda de la gloria",
      posts: "Posts",
      postsDesc: "Noticias y análisis de F1",
      predictions: "Predictions",
      predictionsDesc: "Simula campeonatos y escenarios",
      f1hub: "OverCutHub",
      f1hubDesc: "Big Data, rankings y gráficas",
      about: "¿Qué es OverCut?",
      aboutDesc: "Conoce el proyecto y sus módulos",
      ranking: "Ranking",
      rankingDesc: "Puntos, rangos y clasificación",
      open: "Entrar"
    },
    en: {
      title: "Welcome to OverCut",
      subtitle: "Pick a section to start",
      quiz: "Quiz",
      quizDesc: "Prove your F1 knowledge",
      games: "OverCutGames",
      gamesDesc: "Minigames and challenges",
      draft: "OverCutDraft",
      draftDesc: "Draft historic teams and drivers to play and simulate fictional championships",
      careerMode: "OverCutCareer",
      careerModeDesc: "Create your own driver and live out their racing career in pursuit of glory",
      posts: "Posts",
      postsDesc: "F1 news & analysis",
      predictions: "Predictions",
      predictionsDesc: "Simulate championships & scenarios",
      f1hub: "OverCutHub",
      f1hubDesc: "Big Data, rankings & charts",
      about: "What is OverCut?",
      aboutDesc: "Learn about the project",
      ranking: "Ranking",
      rankingDesc: "Points, tiers and leaderboard",
      open: "Open"
    }
  }[lang]; 


    const tiles = [
      {
        key: "quiz",
        title: t.quiz,
        desc: t.quizDesc,
        img: getAboutOvercutImage("QuizIntro.png"),
        onClick: () => navigate(isLogged ? "/category/2" : "/quiz-info")
      },
      {
        key: "games",
        title: t.games,
        desc: t.gamesDesc,
        img: getAboutOvercutImage("OverCutGames.png"),
        onClick: () => navigate(isLogged ? "/minigames" : "/overcutgames-info")
      },

     {
      key: "careerMode",
      title: t.careerMode,
      desc: t.careerModeDesc,
      img: getAboutOvercutImage("CareerMode.png"),
      onClick: () => window.location.href = "/careerMode"
    },

      {
        key: "draft",
        title: t.draft,
        desc: t.draftDesc,
        img: getAboutOvercutImage("OverCutDraft.png"),
        onClick: () => window.location.href = "/overcutDraft"
      },
      {
        key: "predictions",
        title: t.predictions,
        desc: t.predictionsDesc,
        img: getAboutOvercutImage("OverCutPredictions.png"),
        onClick: () => window.location.href = "/overcutPredictions/"
      },
      {
        key: "f1hub",
        title: t.f1hub,
        desc: t.f1hubDesc,
        img: getAboutOvercutImage("F1HubTables.png"),
        onClick: () => window.location.href = "/overcuthub/"
      },
      {
        key: "posts",
        title: t.posts,
        desc: t.postsDesc,
        img: getAboutOvercutImage("Posts.png"),
        onClick: () => navigate("/posts")
      },
      {
        key: "about",
        title: t.about,
        desc: t.aboutDesc,
        img: getAboutOvercutImage("OverCut.png"),
        onClick: () => navigate("/about")
      }
    ];

    return (
      <div className="start-home">
        <div className="start-home__hero">
          <img
            src="/LogoOverCut.png"
            alt="OverCut"
            className="start-home__logo"
          />
          <p className="start-home__subtitle">{t.subtitle}</p>
        </div>

        <div className="start-home__grid">
          {tiles.map(tile => (
            <button
              key={tile.key}
              className="start-tile"
              onClick={tile.onClick}
              style={{ backgroundImage: `url(${tile.img})` }}
              type="button"
            >
              <div className="start-tile__overlay" />
              <div className="start-tile__content">
                <div className="start-tile__title">{tile.title}</div>
                <div className="start-tile__desc">{tile.desc}</div>
                <div className="start-tile__cta">{t.open} →</div>
              </div>
            </button>
          ))}
        </div>
      </div>
    );
  };

  export default StartHome;
