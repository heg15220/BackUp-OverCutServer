// frontend/src/modules/tower/components/TowerGuessBox.jsx
import React, { useEffect, useMemo, useRef, useState } from "react";
import { useDispatch, useSelector } from "react-redux";
import backend from "../../../backend";
import * as actions from "../actions";
import { getUser } from "../../users/selectors";

import "./TowerGame.css";

const getLabel = (s) => (typeof s === "string" ? s : s?.driverName || "");
const getId = (s) => (typeof s === "string" ? null : (s?.driverId ?? null));

const norm = (v) => (v || "").trim().toLowerCase();

const TowerGuessBox = ({ lang, gameId, disabled }) => {
  const dispatch = useDispatch();

  const [q, setQ] = useState("");
  const [suggestions, setSuggestions] = useState([]);
  const [open, setOpen] = useState(false);
  const [loadingSug, setLoadingSug] = useState(false);

  const [highlightedIndex, setHighlightedIndex] = useState(-1);
  const listRef = useRef([]);
  const inputRef = useRef(null);
  const debounceRef = useRef(null);

  const user = useSelector(getUser);

  const t = useMemo(
    () => ({
      placeholder: lang === "es" ? "Escribe un piloto..." : "Type a driver...",
      button: lang === "es" ? "Probar" : "Try",
      noResults: lang === "es" ? "Sin resultados" : "No results",
    }),
    [lang]
  );

  const closeMobileKeyboard = () => {
    if (!inputRef.current) return;
    inputRef.current.blur();
    setTimeout(() => inputRef.current?.blur?.(), 0);
  };

  useEffect(() => {
    if (highlightedIndex >= 0 && listRef.current[highlightedIndex]) {
      listRef.current[highlightedIndex].scrollIntoView({
        behavior: "smooth",
        block: "nearest",
      });
    }
  }, [highlightedIndex]);

  useEffect(() => {
    if (debounceRef.current) clearTimeout(debounceRef.current);

    const trimmed = q.trim();
    if (!trimmed || trimmed.length < 2) {
      setSuggestions([]);
      setOpen(false);
      setHighlightedIndex(-1);
      return;
    }

    debounceRef.current = setTimeout(() => {
      setLoadingSug(true);

      backend.towerService.autocomplete(
        gameId,
        trimmed,
        user,
        (res) => {
          const arr = Array.isArray(res) ? res : [];
          setSuggestions(arr);
          setOpen(true);
          setHighlightedIndex(arr.length ? 0 : -1);
          setLoadingSug(false);
        },
        () => {
          setSuggestions([]);
          setOpen(true);
          setHighlightedIndex(-1);
          setLoadingSug(false);
        }
      );
    }, 200);

    return () => {
      if (debounceRef.current) clearTimeout(debounceRef.current);
    };
  }, [q, gameId, user]); // ✅ user incluido

  const resetBox = () => {
    setQ("");
    setOpen(false);
    setSuggestions([]);
    setHighlightedIndex(-1);
  };

  const pickSuggestion = (s) => {
    const name = getLabel(s);
    if (!name) return;

    const driverId = getId(s);
    dispatch(actions.guessTower(gameId, driverId, name));
    resetBox();
    closeMobileKeyboard();
  };

  const onSubmit = (e) => {
    e.preventDefault();
    if (disabled) return;

    const trimmed = q.trim();
    if (!trimmed) return;

    // ✅ Si escribió exacto el nombre de alguna sugerencia -> cogemos driverId
    const match = suggestions.find((s) => norm(getLabel(s)) === norm(trimmed));
    const driverId = match ? getId(match) : null;

    if (!driverId) return; // ✅ obliga a elegir del autocomplete

    dispatch(actions.guessTower(gameId, driverId));


     resetBox();
    closeMobileKeyboard();
  };

  const onKeyDown = (e) => {
    if (disabled) return;

    const hasSug = suggestions.length > 0;

    if (e.key === "ArrowDown") {
      if (!hasSug) return;
      e.preventDefault();
      setOpen(true);
      setHighlightedIndex((prev) => {
        const next = prev < 0 ? 0 : (prev + 1) % suggestions.length;
        return next;
      });
    } else if (e.key === "ArrowUp") {
      if (!hasSug) return;
      e.preventDefault();
      setOpen(true);
      setHighlightedIndex((prev) => {
        if (prev < 0) return suggestions.length - 1;
        return prev <= 0 ? suggestions.length - 1 : prev - 1;
      });
    } else if (e.key === "Enter") {
      if (open && highlightedIndex >= 0 && suggestions[highlightedIndex]) {
        e.preventDefault();
        pickSuggestion(suggestions[highlightedIndex]);
        return;
      }
    } else if (e.key === "Escape") {
      setOpen(false);
      setHighlightedIndex(-1);
      closeMobileKeyboard();
    }
  };

  return (
    <div className={`tower-guess ${disabled ? "isDisabled" : ""}`}>
      <form onSubmit={onSubmit} className="tower-guessForm">
        <div className="tower-searchWrap">
          <input
            ref={inputRef}
            className="tower-input"
            value={q}
            onChange={(e) => {
              setQ(e.target.value);
              setHighlightedIndex(-1);
            }}
            placeholder={t.placeholder}
            disabled={disabled}
            onKeyDown={onKeyDown}
            onFocus={() => suggestions.length && setOpen(true)}
            onBlur={() => setTimeout(() => setOpen(false), 120)}
            autoComplete="off"
          />

          {open && !disabled && (
            <div className="tower-suggest">
              {loadingSug ? (
                <div className="tower-suggestItem tower-suggestMuted">...</div>
              ) : suggestions.length ? (
                suggestions.slice(0, 10).map((s, idx) => {
                  const label = getLabel(s);
                  const id = getId(s);
                  return (
                    <button
                      type="button"
                      key={`${label}-${id ?? idx}`}
                      ref={(el) => (listRef.current[idx] = el)}
                      className={`tower-suggestItem ${
                        highlightedIndex === idx ? "selected" : ""
                      }`}
                      onMouseDown={(e) => {
                        e.preventDefault();
                        pickSuggestion(s);
                      }}
                      onMouseEnter={() => setHighlightedIndex(idx)}
                    >
                      {label}
                    </button>
                  );
                })
              ) : (
                <div className="tower-suggestItem tower-suggestMuted">
                  {t.noResults}
                </div>
              )}
            </div>
          )}
        </div>

        <button className="tower-tryBtn" type="submit" disabled={disabled}>
          {t.button}
        </button>
      </form>
    </div>
  );
};

export default TowerGuessBox;
