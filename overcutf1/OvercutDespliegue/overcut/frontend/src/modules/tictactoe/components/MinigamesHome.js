// MinigamesHome.js
import React, { useMemo } from "react";
import { Link, useSearchParams } from "react-router-dom";
import "./MinigamesHome.css";
import { sourceImages } from "../../../helpers/sourceMiniGamesImages";

const minigames = [
  {
    path: "/minigames/tictactoe",
    title: "Tic Tac Toe",
    description: "Consigue 3 en raya adivinando pilotos",
    img: sourceImages(`./tictactoe.png`)
  },
  {
    path: "/minigames/crossword",
    title: "Crossword",
    description: "Rellena el crucigrama de Fórmula 1",
    img: sourceImages(`./crossword.png`)
  },
  {
    path: "/minigames/gridgame",
    title: "Grid",
    description: "Acierta pilotos por nacionalidad",
    img: sourceImages(`./F1Grid.png`)
  },
  {
    path: "/minigames/guessdriver",
    title: "Guess Driver",
    description: "Haz preguntas para descubrir al piloto",
    img: sourceImages(`./GuessDriver.png`)
  },
  {
    path: "/minigames/top10",
    title: "Top 10",
    description: "Adivina el top 10 de una carrera",
    img: sourceImages(`./top10.png`)
  },
  {
    path: "/minigames/driverslink",
    title: "Drivers Link",
    description: "Adivina al piloto por sus compañeros",
    img: sourceImages(`./DriversLink.png`)
  },
  {
    path: "/minigames/rondo",
    title: "Rondo",
    description: "Acierta palabras del rosco F1",
    img: sourceImages(`./Rondo.png`)
  },
  {
    path: "/minigames/careerpath",
    title: "Career Path",
    description: "Adivina al piloto por sus equipos",
    img: sourceImages(`./CareerPath.png`)
  },
  {
    path: "/minigames/wordle",
    title: "Wordle",
    description: "Adivina el apellido de un piloto F1",
    img: sourceImages(`./F1Wordle.png`)
  },
  {
    path: "/minigames/twoTeams",
    title: "2 Teams, 1 Driver",
    description: "Acierta un piloto que corrió para ambos equipos",
    img: sourceImages(`./TwoTeams.png`)
  },
  {
    path: "/minigames/f1Impostor",
    title: "Impostors",
    description: "Evita a los impostores en un reto temático",
    img: sourceImages(`./F1Impostors.png`)
  },
  {
    path: "/minigames/teamGuess",
    title: "Guess the Team",
    description: "Adivina el equipo por sus pilotos",
    img: sourceImages(`./GuessTeam.png`)
  },
  {
    path: "/minigames/driversConnections",
    title: "Drivers Connection",
    description: "Agrupa 4 pilotos que compartan una categoría secreta",
    img: sourceImages(`./DriversConnection.png`)
  },
  {
    path: "/minigames/orderDrivers",
    title: "Sort Drivers",
    description: "Ordena a los pilotos según el criterio F1",
    img: sourceImages(`./OrderDriversGame.png`)
  },
  {
    path: "/minigames/categoryGame",
    title: "Categories",
    description: "Responde categorías que empiezan con la misma letra",
    img: sourceImages(`./gameCategory.png`)
  },
  {
    path: "/minigames/wordSearch",
    title: "Word Search",
    description: "Encuentra apellidos de pilotos con podios",
    img: sourceImages(`./searchGame.png`)
  },
  {
    path: "/minigames/top10quali",
    title: "Top 10 Quali",
    description: "Adivina el top 10 de una clasificación",
    img: sourceImages(`./top10quali.png`)
  },
  {
    path: "/minigames/driverSeason",
    title: "Driver Season",
    description: "Adivina la posición final del piloto en cada carrera",
    img: sourceImages(`./DriverSeason.png`)
  },
  {
    path: "/minigames/tower",
    title: "Tower",
    description: "Prueba si un piloto entra en una temática secreta",
    img: sourceImages(`./Tower2.png`)
  },
  {
    path: "/minigames/lightsout",
    title: "Lights Out",
    description: "Reacciona al semáforo",
    img: sourceImages(`./LightsOut.png`)
  },
  {
    path: "/minigames/anagrams",
    title: "Anagrams",
    description: "Reordena letras para adivinar el apellido",
    img: sourceImages(`./Anagrams.png`)
  },
  {
    path: "/minigames/bingo",
    title: "Bingo",
    description: "Completa un bingo de 9 casillas",
    img: sourceImages(`./bingo.png`)
  },
  {
    path: "/games/race",
    title: { es: "OverCut Racing", en: "OverCut Racing" },
    description: {
      es: "Carrera 2D contra IA",
      en: "2D racing vs AI"
    },
    img: sourceImages(`./RaceGame.png`)
  },
  {
    path: "/minigames/timeline",
    title: { es: "Timeline", en: "Timeline" },
    description: {
      es: "Ordena eventos históricos",
      en: "Sort historical events"
    },
    img: sourceImages(`./Timeline2.png`)
  },
  {
    path: "/minigames/whoIsWho",
    title: { es: "Who Am I", en: "Who Am I" },
    description: {
      es: "Adivina el piloto con pistas",
      en: "Guess the driver using hints"
    },
    img: sourceImages(`./WhoAmI2.png`)
  },

  
{
  path: "/minigames/memory",
  title: { es: "Memory", en: "Memory" },
  description: {
    es: "Encuentra parejas relacionadas (piloto-equipo, piloto-nacionalidad, etc.)",
    en: "Find related pairs (driver-team, driver-nationality, etc.)"
  },
  img: sourceImages("./Memory.png")
},

{
  path: "/minigames/teamHistory",
  title: "Team History",
  description: "Adivina la posición final del equipo en el mundial de constructores en cada temporada",
  img: sourceImages(`./TeamHistory.png`)
},

{
  path: "/minigames/higherLower",
  title: "Higher or Lower",
  description: "Compara estadísticas de pilotos (wins, podiums, points...)",
  img: sourceImages(`./HigherLower.png`)
},
{
  path: "/minigames/thirtySeconds",
  title: { es: "30 Seconds", en: "30 Seconds" },
  description: {
    es: "Escribe tantos pilotos como puedas en 30 segundos según la temática mostrada",
    en: "Type as many drivers as you can in 30 seconds based on the shown theme"
  },
  img: sourceImages("./ThirtySeconds2.png")
},

{
  path: "/minigames/driverStats",
  title: { es: "Driver Stats", en: "Driver Stats" },
  description: {
    es: "Adivina estadísticas del piloto (carreras y puntos por rangos)",
    en: "Guess driver stats (races and points by ranges)"
  },
  img: sourceImages("./DriverStats.png")
},


{
  path: "/minigames/abbreviations",
  title: { es: "Abbreviations", en: "Abbreviations" },
  description: {
    es: "Adivina pilotos por abreviaturas de 3 letras",
    en: "Guess drivers from 3-letter abbreviations"
  },
  img: sourceImages("./Abbreviations2.png")
},
{
  path: "/minigames/teamNationality",
  title: { es: "Equipo & Nacionalidad", en: "Team & Nationality" },
  description: {
    es: "Acierta pilotos que cumplan relación país-equipo (bandera + team)",
    en: "Guess drivers matching a nationality-team pair (flag + team)"
  },
  img: sourceImages("./TeamNationality2.png")
},




];

const translations = {
  subtitle: {
    es: "¡Demuestra tu conocimiento sobre Fórmula 1 jugando!",
    en: "Prove your Formula 1 knowledge by playing!"
  },
  play: {
    es: "Jugar",
    en: "Play"
  }
};

const PAGE_SIZE = 16;

// 🔥 Función robusta para soportar string o {es,en}
const getI18nText = (value, lang) => {
  if (!value) return "";
  if (typeof value === "string") return value;
  if (typeof value === "object") return value[lang] || value.es || value.en || "";
  return String(value);
};

const MinigamesHome = () => {
  const lang = navigator.language.startsWith("es") ? "es" : "en";

  const [searchParams, setSearchParams] = useSearchParams();
  const rawPage = Number(searchParams.get("page") || "1");
  const totalPages = Math.max(1, Math.ceil(minigames.length / PAGE_SIZE));

  const page = Number.isFinite(rawPage)
    ? Math.min(Math.max(rawPage, 1), totalPages)
    : 1;

  const pageItems = useMemo(() => {
    const start = (page - 1) * PAGE_SIZE;
    return minigames.slice(start, start + PAGE_SIZE);
  }, [page]);

  const goToPage = (p) => {
    const safe = Math.min(Math.max(p, 1), totalPages);
    setSearchParams({ page: String(safe) });
    window.scrollTo({ top: 0, behavior: "smooth" });
  };

  const pages = useMemo(
    () => Array.from({ length: totalPages }, (_, i) => i + 1),
    [totalPages]
  );

  return (
    <div className="minigames-page">
      <div className="minigames-header animate__animated animate__fadeIn">
        <h1 className="minigames-title">
          OverCut<span className="highlight">Games</span>
        </h1>
        <p className="minigames-subtitle">
          {translations.subtitle[lang]}
        </p>
      </div>

      <div className="games">
        {pageItems.map((game, index) => (
          <Link
            to={game.path}
            key={`${game.path}-${index}`}
            className="gameThumbnailLink animate__animated animate__fadeIn"
          >
            <div className="cardDiv">
              <img
                src={game.img}
                alt={getI18nText(game.title, lang)}
                className="gameImage"
              />
              <div className="text">
                <p className="playLabel">{translations.play[lang]}</p>
                <p className="gameTitle">
                  {getI18nText(game.title, lang)}
                </p>
              </div>
            </div>
          </Link>
        ))}
      </div>

      {totalPages > 1 && (
        <div className="minigames-pagination">
          <button
            className="page-nav"
            onClick={() => goToPage(page - 1)}
            disabled={page === 1}
          >
            ‹
          </button>

          {pages.map((p) => (
            <button
              key={p}
              className={`page-number ${p === page ? "active" : ""}`}
              onClick={() => goToPage(p)}
            >
              {p}
            </button>
          ))}

          <button
            className="page-nav"
            onClick={() => goToPage(page + 1)}
            disabled={page === totalPages}
          >
            ›
          </button>
        </div>
      )}
    </div>
  );
};

export default MinigamesHome;
