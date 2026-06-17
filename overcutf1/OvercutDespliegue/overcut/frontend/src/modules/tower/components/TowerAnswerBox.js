// frontend/src/modules/tower/components/TowerAnswerBox.jsx
import React, { useEffect, useMemo, useRef, useState } from "react";
import { useDispatch, useSelector } from "react-redux";
import backend from "../../../backend";
import * as actions from "../actions";
import { getUser } from "../../users/selectors";

const MIN_ATTEMPTS_TO_ANSWER = 5;

const getLabel = (s) => (typeof s === "string" ? s : s?.driverName || "");
const getId = (s) => (typeof s === "string" ? null : (s?.driverId ?? null));
const norm = (v) => (v || "").trim().toLowerCase();

const TowerAnswerBox = ({ lang, gameId, themesCatalog, attempts }) => {
  const dispatch = useDispatch();
  const user = useSelector(getUser);

  const [themeType, setThemeType] = useState("");
  const [themeKey, setThemeKey] = useState("");

  // driver-mode state
  const [driverQ, setDriverQ] = useState("");
  const [driverSuggestions, setDriverSuggestions] = useState([]);
  const [driverOpen, setDriverOpen] = useState(false);
  const [driverLoading, setDriverLoading] = useState(false);
  const [selectedDriver, setSelectedDriver] = useState(null); // {driverId, driverName} | null

  const driverDebounceRef = useRef(null);

  const t = useMemo(() => {
    return {
      title: lang === "es" ? "🎯 Responder" : "🎯 Answer",
      theme: lang === "es" ? "Temática" : "Theme",
      option: lang === "es" ? "Respuesta" : "Answer",
      send: lang === "es" ? "Enviar" : "Submit",
      pickTheme: lang === "es" ? "— Selecciona temática —" : "— Select theme —",
      pickOption: lang === "es" ? "— Selecciona opción —" : "— Select option —",
      locked:
        lang === "es"
          ? `Disponible tras ${MIN_ATTEMPTS_TO_ANSWER} intentos`
          : `Available after ${MIN_ATTEMPTS_TO_ANSWER} attempts`,
      pickDriver: lang === "es" ? "Escribe un piloto..." : "Type a driver...",
      noResults: lang === "es" ? "Sin resultados" : "No results",
      driverLabel: lang === "es" ? "Piloto" : "Driver",
      mustPickDriver:
        lang === "es"
          ? "Selecciona un piloto del autocomplete."
          : "Pick a driver from autocomplete.",
    };
  }, [lang]);

  const themes = themesCatalog?.themes || [];
  const selectedTheme = themes.find((x) => x.type === themeType);

  const requiresKey = !!selectedTheme?.requiresKey;
  const options = selectedTheme?.options || [];
  const keyKind = selectedTheme?.keyKind || null;

  const canAnswer = attempts >= MIN_ATTEMPTS_TO_ANSWER;

  // reset cuando cambias theme
  useEffect(() => {
    setThemeKey("");
    setDriverQ("");
    setDriverSuggestions([]);
    setDriverOpen(false);
    setDriverLoading(false);
    setSelectedDriver(null);
  }, [themeType]);

  // driver autocomplete (solo si keyKind === "driver")
  useEffect(() => {
    if (keyKind !== "driver") return;

    if (driverDebounceRef.current) clearTimeout(driverDebounceRef.current);

    const trimmed = driverQ.trim();
    if (!trimmed || trimmed.length < 2) {
      setDriverSuggestions([]);
      setDriverOpen(false);
      setDriverLoading(false);
      return;
    }

    driverDebounceRef.current = setTimeout(() => {
      setDriverLoading(true);

      // ✅ FIX: pasar 'user' con firma correcta
      backend.towerService.autocomplete(
        gameId,
        trimmed,
        user,
        (res) => {
          const arr = Array.isArray(res) ? res : [];
          setDriverSuggestions(arr);
          setDriverOpen(true);
          setDriverLoading(false);
        },
        () => {
          setDriverSuggestions([]);
          setDriverOpen(true);
          setDriverLoading(false);
        }
      );
    }, 200);

    return () => {
      if (driverDebounceRef.current) clearTimeout(driverDebounceRef.current);
    };
  }, [driverQ, keyKind, gameId, user]);

  const pickDriver = (s) => {
    const id = getId(s);
    const name = getLabel(s);
    if (!id || !name) return;

    setSelectedDriver({ driverId: id, driverName: name });
    setDriverQ(name);
    setDriverOpen(false);
  };

  const canSubmit = useMemo(() => {
    if (!canAnswer) return false;
    if (!themeType) return false;

    if (!requiresKey) return true;

    if (keyKind === "driver") {
      return !!selectedDriver?.driverId;
    }

    return !!(themeKey && themeKey.trim());
  }, [canAnswer, themeType, requiresKey, keyKind, selectedDriver, themeKey]);

  const submit = () => {
    if (!canSubmit) return;

    // si es driver-mode, themeKey debe ser el driverId en string
    const finalKey =
      keyKind === "driver" ? String(selectedDriver.driverId) : themeKey;

    dispatch(actions.answerTower(gameId, themeType, finalKey));
  };

  return (
    <div className="tower-answerCard">
      <div className="tower-answerTitle">{t.title}</div>

      <label className="tower-label">{t.theme}</label>
      <select
        className="tower-select"
        value={themeType}
        disabled={!canAnswer}
        onChange={(e) => setThemeType(e.target.value)}
      >
        <option value="">{t.pickTheme}</option>
        {themes.map((th) => (
          <option key={th.type} value={th.type}>
            {th.type}
          </option>
        ))}
      </select>

      {/* key normal (no driver) */}
      {themeType && requiresKey && keyKind !== "driver" && (
        <>
          <label className="tower-label" style={{ marginTop: 10 }}>
            {t.option}
          </label>
          <select
            className="tower-select"
            value={themeKey}
            disabled={!canAnswer}
            onChange={(e) => setThemeKey(e.target.value)}
          >
            <option value="">{t.pickOption}</option>
            {options.map((op) => (
              <option key={op.value} value={op.value}>
                {op.label}
              </option>
            ))}
          </select>
        </>
      )}

      {/* keyKind driver */}
      {themeType && requiresKey && keyKind === "driver" && (
        <div style={{ marginTop: 10 }}>
          <label className="tower-label">{t.driverLabel}</label>

          <div className="tower-searchWrap">
            <input
              className="tower-input"
              value={driverQ}
              disabled={!canAnswer}
              placeholder={t.pickDriver}
              onChange={(e) => {
                const v = e.target.value;
                setDriverQ(v);

                // si el usuario edita a mano, invalidamos selección previa
                if (selectedDriver && norm(v) !== norm(selectedDriver.driverName)) {
                  setSelectedDriver(null);
                }
              }}
              onFocus={() => driverSuggestions.length && setDriverOpen(true)}
              onBlur={() => setTimeout(() => setDriverOpen(false), 120)}
              autoComplete="off"
            />

            {driverOpen && canAnswer && (
              <div className="tower-suggest">
                {driverLoading ? (
                  <div className="tower-suggestItem tower-suggestMuted">...</div>
                ) : driverSuggestions.length ? (
                  driverSuggestions.slice(0, 10).map((s, idx) => {
                    const label = getLabel(s);
                    const id = getId(s);
                    return (
                      <button
                        type="button"
                        key={`${label}-${id ?? idx}`}
                        className="tower-suggestItem"
                        onMouseDown={(e) => {
                          e.preventDefault();
                          pickDriver(s);
                        }}
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

          {canAnswer && !selectedDriver && (
            <div className="tower-muted" style={{ marginTop: 8 }}>
              {t.mustPickDriver}
            </div>
          )}
        </div>
      )}

      {!canAnswer && (
        <div className="tower-muted" style={{ marginTop: 10 }}>
          {t.locked}
        </div>
      )}

      <div className="tower-setupActions" style={{ marginTop: 12 }}>
        <button
          className="tower-tryBtn"
          type="button"
          disabled={!canSubmit}
          onClick={submit}
        >
          {t.send}
        </button>
      </div>
    </div>
  );
};

export default TowerAnswerBox;
