import React, { useEffect, useMemo, useState, useCallback } from "react";
import { useDispatch, useSelector } from "react-redux";
import { DndContext, closestCenter, useSensor, useSensors, PointerSensor } from "@dnd-kit/core";
import { SortableContext, verticalListSortingStrategy, arrayMove, useSortable } from "@dnd-kit/sortable";
import { CSS } from "@dnd-kit/utilities";

import predictions from "../index";
import "./styles/SimulationPanel.css";
import { pointsForPosition } from "./pointsEras";
import { t } from "../../../i18n/translations";

/* --------------------------------------------- */
/* ✅ Sprint points (UI)                          */
/* --------------------------------------------- */
function sprintPointsForPosition(pos, mode) {
  const p = Number(pos);

  if (mode === "TOP3_3_2_1") {
    if (p === 1) return 3;
    if (p === 2) return 2;
    if (p === 3) return 1;
    return 0;
  }

  // default: TOP8_8_TO_1
  // 1->8, 2->7, ... 8->1
  if (p >= 1 && p <= 8) return 9 - p;
  return 0;
}

function SortableDriverRow({ driver, points, isSelected, onClick }) {
  const { attributes, listeners, setNodeRef, transform, transition, isDragging } = useSortable({
    id: driver.driverId,
  });

  const style = {
    transform: CSS.Transform.toString(transform),
    transition,
    opacity: isDragging ? 0.7 : 1,
  };

  return (
    <div
      ref={setNodeRef}
      style={style}
      className={`sim-row ${isDragging ? "dragging" : ""} ${isSelected ? "selected" : ""}`}
      {...attributes}
      {...listeners}
      role="button"
      tabIndex={0}
      onClick={(e) => {
        e.stopPropagation();
        onClick(driver.driverId);
      }}
      onKeyDown={(e) => {
        if (e.key === "Enter" || e.key === " ") {
          e.preventDefault();
          onClick(driver.driverId);
        }
      }}
    >
      <div className="sim-row__name">
        <div className="sim-row__driver">{driver.driverName}</div>
      </div>

      <div className="sim-row__pts" aria-label={t("sim.ariaPoints", { points })}>
        {points}
        <span className="sim-row__ptsUnit">pts</span>
      </div>
    </div>
  );
}

function buildOrderFromStandings(driverStandings, fallbackIds) {
  if (!Array.isArray(driverStandings) || driverStandings.length === 0) return fallbackIds;

  const getId = (x) => x?.entityId ?? x?.driverId ?? x?.driver?.driverId ?? x?.id;
  const getPts = (x) => x?.points ?? x?.pts ?? 0;
  const getPos = (x) => x?.position ?? x?.pos ?? null;

  const rows = driverStandings
    .map((x) => ({ id: getId(x), pts: getPts(x), pos: getPos(x) }))
    .filter((r) => r.id != null);

  if (rows.length === 0) return fallbackIds;

  const hasPos = rows.some((r) => r.pos != null);

  rows.sort((a, b) => {
    if (hasPos) return (a.pos ?? 9999) - (b.pos ?? 9999);
    return (b.pts ?? 0) - (a.pts ?? 0);
  });

  const ordered = rows.map((r) => r.id);
  const set = new Set(ordered);
  const rest = fallbackIds.filter((id) => !set.has(id));
  return [...ordered, ...rest];
}

export default function SimulationPanel() {
  const dispatch = useDispatch();

  const season = useSelector(predictions.selectors.getSeason);
  const fromRound = useSelector(predictions.selectors.getFromRound);
  const totalRounds = useSelector(predictions.selectors.getTotalRounds);
  const raceNamesByRound = useSelector(predictions.selectors.getRaceNamesByRound);

  const driverStandings = useSelector(predictions.selectors.getDriverStandings);
  const constructorStandings = useSelector(predictions.selectors.getConstructorStandings);
  const driverToConstructor = useSelector(predictions.selectors.getDriverToConstructor);
  const seasonDrivers = useSelector(predictions.selectors.getSeasonDrivers);

  const pointsEra = useSelector(predictions.selectors.getPointsEra);
  const customConfig = useSelector(predictions.selectors.getCustomConfig);

  // ✅ NUEVO: sprint rounds reales (modo db)
  const sprintRoundsFromBootstrap = useSelector(predictions.selectors.getSprintRounds);

  const canUse = !!season && !!fromRound;

  const [round, setRound] = useState(fromRound || 1);

  const [orderedIds, setOrderedIds] = useState([]);
  const [selectedId, setSelectedId] = useState(null);
  const [dirtyOrder, setDirtyOrder] = useState(false);

  // ✅ Sprint UI
  const [simulateSprint, setSimulateSprint] = useState(false);
  const [orderedIdsSprint, setOrderedIdsSprint] = useState([]);
  const [selectedIdSprint, setSelectedIdSprint] = useState(null);
  const [dirtyOrderSprint, setDirtyOrderSprint] = useState(false);

  const sensors = useSensors(useSensor(PointerSensor, { activationConstraint: { distance: 6 } }));

  // ✅ Set unificado: sprints reales de BD + customSprints (si las hay)
  const sprintRoundsSet = useMemo(() => {
    const fromDb = (sprintRoundsFromBootstrap || []).map((x) => Number(x));
    const fromCustom = (customConfig?.customSprints || []).map((s) => Number(s?.round));
    return new Set([...fromDb, ...fromCustom].filter((n) => Number.isFinite(n)));
  }, [sprintRoundsFromBootstrap, customConfig]);

  useEffect(() => {
    if (!canUse) return;
    if (!seasonDrivers || seasonDrivers.length === 0) return;

    setRound(fromRound);

    const fallback = seasonDrivers.map((d) => d.driverId);
    setOrderedIds(buildOrderFromStandings(driverStandings, fallback));

    // sprint list por defecto = mismo orden
    setOrderedIdsSprint(buildOrderFromStandings(driverStandings, fallback));

    setSelectedId(null);
    setDirtyOrder(false);

    setSelectedIdSprint(null);
    setDirtyOrderSprint(false);

    // ✅ Auto sprint: ahora vale para db (sprintRounds) y custom (customSprints)
    setSimulateSprint(sprintRoundsSet.has(Number(fromRound)));

    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [canUse, fromRound, seasonDrivers, sprintRoundsSet]);

  const roundOptions = useMemo(() => {
    if (!canUse) return [];
    const max = totalRounds || 30;
    const list = [];
    for (let r = fromRound; r <= max; r++) {
      list.push({ r, name: raceNamesByRound?.[r] || raceNamesByRound?.[String(r)] || `Round ${r}` });
    }
    return list;
  }, [canUse, fromRound, totalRounds, raceNamesByRound]);

  const currentGpName = raceNamesByRound?.[round] || raceNamesByRound?.[String(round)] || `Round ${round}`;

  const orderedDrivers = useMemo(() => {
    const map = new Map((seasonDrivers || []).map((d) => [d.driverId, d]));
    return (orderedIds || []).map((id) => map.get(id)).filter(Boolean);
  }, [orderedIds, seasonDrivers]);

  const orderedDriversSprint = useMemo(() => {
    const map = new Map((seasonDrivers || []).map((d) => [d.driverId, d]));
    return (orderedIdsSprint || []).map((id) => map.get(id)).filter(Boolean);
  }, [orderedIdsSprint, seasonDrivers]);

  const onDragEndRace = (event) => {
    const { active, over } = event;
    if (!over || active.id === over.id) return;

    const oldIndex = orderedIds.indexOf(active.id);
    const newIndex = orderedIds.indexOf(over.id);

    if (oldIndex !== -1 && newIndex !== -1) {
      setOrderedIds((items) => arrayMove(items, oldIndex, newIndex));
      setSelectedId(null);
      setDirtyOrder(true);
    }
  };

  const onDragEndSprint = (event) => {
    const { active, over } = event;
    if (!over || active.id === over.id) return;

    const oldIndex = orderedIdsSprint.indexOf(active.id);
    const newIndex = orderedIdsSprint.indexOf(over.id);

    if (oldIndex !== -1 && newIndex !== -1) {
      setOrderedIdsSprint((items) => arrayMove(items, oldIndex, newIndex));
      setSelectedIdSprint(null);
      setDirtyOrderSprint(true);
    }
  };

  const handleRowClickRace = useCallback((driverId) => {
    setSelectedId((prev) => {
      if (prev == null) return driverId;
      if (prev === driverId) return null;

      setOrderedIds((ids) => {
        const a = ids.indexOf(prev);
        const b = ids.indexOf(driverId);
        if (a === -1 || b === -1) return ids;

        const next = [...ids];
        [next[a], next[b]] = [next[b], next[a]];
        return next;
      });

      setDirtyOrder(true);
      return null;
    });
  }, []);

  const handleRowClickSprint = useCallback((driverId) => {
    setSelectedIdSprint((prev) => {
      if (prev == null) return driverId;
      if (prev === driverId) return null;

      setOrderedIdsSprint((ids) => {
        const a = ids.indexOf(prev);
        const b = ids.indexOf(driverId);
        if (a === -1 || b === -1) return ids;

        const next = [...ids];
        [next[a], next[b]] = [next[b], next[a]];
        return next;
      });

      setDirtyOrderSprint(true);
      return null;
    });
  }, []);

  const canApply = canUse && orderedIds.length > 0;

  const sprintPointsMode = customConfig?.sprintPointsMode || "TOP8_8_TO_1";

  const buildPayload = () => ({
    season: Number(season),
    pointsEra: pointsEra != null ? Number(pointsEra) : null,

    // ✅ sprint points mode para backend
    sprintPointsMode,

    driverStandings,
    constructorStandings,
    race: {
      round: Number(round),
      orderedDriverIds: orderedIds,
      orderedDriverIdsSprint: simulateSprint ? orderedIdsSprint : null,
    },
    driverToConstructor,
  });

  const apply = () => {
    if (!canApply) return;
    dispatch(predictions.actions.applySimulation(buildPayload()));
  };

  const maxRound = totalRounds || 30;
  const canNext = canApply && Number(round) < Number(maxRound);

  const next = () => {
    if (!canNext) return;
    dispatch(predictions.actions.applySimulation(buildPayload()));

    const nextRound = Number(round) + 1;
    setRound(nextRound);

    setSelectedId(null);
    setDirtyOrder(false);

    setSelectedIdSprint(null);
    setDirtyOrderSprint(false);

    // ✅ Auto sprint: db + custom
    setSimulateSprint(sprintRoundsSet.has(nextRound));
  };

  if (!canUse) {
    return (
      <div className="sim-card">
        <div className="sim-card__head">
          <div className="sim-card__title">
            <h2>{t("sim.title")}</h2>
            <span className="sim-card__sub">{t("sim.needBootstrap")}</span>
          </div>
        </div>
        <div className="sim-card__empty">{t("sim.empty")}</div>
      </div>
    );
  }

  const gpHasSprint = sprintRoundsSet.has(Number(round));

  return (
    <div className="sim-card">
      <div className="sim-card__head">
        <div className="sim-card__title">
          <h2>{t("sim.title")}</h2>
          <span className="sim-card__sub">{t("sim.subtitle", { season, fromRound, gp: currentGpName })}</span>
        </div>
      </div>

      <div className="sim-card__grid">
        <div className="sim-field">
          <label>{t("sim.gpRound")}</label>

          <select
            className="oc-input sim-select"
            value={round}
            onChange={(e) => {
              const r = Number(e.target.value);
              setRound(r);

              setSelectedId(null);
              setSelectedIdSprint(null);

              const fallback = seasonDrivers.map((d) => d.driverId);

              if (!dirtyOrder) setOrderedIds(buildOrderFromStandings(driverStandings, fallback));
              if (!dirtyOrderSprint) setOrderedIdsSprint(buildOrderFromStandings(driverStandings, fallback));

              // ✅ Auto sprint: db + custom
              setSimulateSprint(sprintRoundsSet.has(r));
            }}
          >
            {roundOptions.map((opt) => (
              <option key={opt.r} value={opt.r}>
                {opt.r}. {opt.name}
              </option>
            ))}
          </select>

          <div className="sim-roundActions">
            <button className="oc-btn" disabled={!canApply} onClick={apply} type="button">
              {t("sim.apply")}
            </button>

            <button className="oc-btn oc-btn--primary" disabled={!canNext} onClick={next} type="button">
              {t("sim.applyNext")}
            </button>

            <button
              className="oc-btn oc-btn--ghost"
              type="button"
              onClick={() => {
                const fallback = seasonDrivers.map((d) => d.driverId);
                setOrderedIds(buildOrderFromStandings(driverStandings, fallback));
                setSelectedId(null);
                setDirtyOrder(false);

                setOrderedIdsSprint(buildOrderFromStandings(driverStandings, fallback));
                setSelectedIdSprint(null);
                setDirtyOrderSprint(false);
              }}
            >
              {t("sim.resetOrder")}
            </button>
          </div>

          {/* ✅ Sprint toggle */}
          <div style={{ marginTop: 10, display: "flex", gap: 10, alignItems: "center" }}>
            <label style={{ display: "flex", gap: 8, alignItems: "center" }}>
              <input
                type="checkbox"
                checked={simulateSprint}
                onChange={(e) => {
                  setSimulateSprint(e.target.checked);
                  if (e.target.checked && (!orderedIdsSprint || orderedIdsSprint.length === 0)) {
                    const fallback = seasonDrivers.map((d) => d.driverId);
                    setOrderedIdsSprint(buildOrderFromStandings(driverStandings, fallback));
                  }
                }}
              />
              {t("sim.simulateSprint") || "Simulate Sprint"}
            </label>

            {gpHasSprint ? (
              <span className="meta-pill meta-pill--soft">{t("sim.sprintReal") || "Real sprint weekend"}</span>
            ) : (
              <span className="meta-pill meta-pill--soft">{t("sim.sprintNotInCalendar") || "No sprint scheduled"}</span>
            )}

            {simulateSprint ? (
              <span className="meta-pill meta-pill--soft">
                {t("sim.sprintPointsMode") || "Sprint points"}: <b>{sprintPointsMode}</b>
              </span>
            ) : null}
          </div>

          <div className="sim-hint">{t("sim.onlyFrom", { fromRound })}</div>
        </div>

        {/* RACE ORDER */}
        <div className="sim-field sim-field--wide">
          <label>{t("sim.finishingOrder")}</label>

          <div className="sim-dnd">
            <div className="sim-dnd__header">
              <span>{t("sim.countDrivers", { n: orderedIds.length })}</span>
              <span className="sim-dnd__hint">{t("sim.dragHint")}</span>
            </div>

            <DndContext sensors={sensors} collisionDetection={closestCenter} onDragEnd={onDragEndRace}>
              <SortableContext items={orderedIds} strategy={verticalListSortingStrategy}>
                <div className="sim-list">
                  {orderedDrivers.map((d, idx) => {
                    const pos = idx + 1;
                    const pts = pointsForPosition(pos, pointsEra ?? season);

                    return (
                      <div key={d.driverId} className="sim-list__item">
                        <div className="sim-list__pos">{pos}</div>
                        <SortableDriverRow
                          driver={d}
                          points={pts}
                          isSelected={selectedId === d.driverId}
                          onClick={handleRowClickRace}
                        />
                      </div>
                    );
                  })}
                </div>
              </SortableContext>
            </DndContext>
          </div>

          {/* SPRINT ORDER */}
          {simulateSprint ? (
            <div style={{ marginTop: 14 }}>
              <label style={{ display: "block", marginBottom: 8 }}>
                {t("sim.finishingOrderSprint") || "Sprint finishing order"}
              </label>

              <div className="sim-dnd">
                <div className="sim-dnd__header">
                  <span>{t("sim.countDrivers", { n: orderedIdsSprint.length })}</span>
                  <span className="sim-dnd__hint">{t("sim.dragHint")}</span>
                </div>

                <DndContext sensors={sensors} collisionDetection={closestCenter} onDragEnd={onDragEndSprint}>
                  <SortableContext items={orderedIdsSprint} strategy={verticalListSortingStrategy}>
                    <div className="sim-list">
                      {orderedDriversSprint.map((d, idx) => {
                        const pos = idx + 1;
                        const pts = sprintPointsForPosition(pos, sprintPointsMode);

                        return (
                          <div key={`s-${d.driverId}`} className="sim-list__item">
                            <div className="sim-list__pos">{pos}</div>
                            <SortableDriverRow
                              driver={d}
                              points={pts}
                              isSelected={selectedIdSprint === d.driverId}
                              onClick={handleRowClickSprint}
                            />
                          </div>
                        );
                      })}
                    </div>
                  </SortableContext>
                </DndContext>
              </div>
            </div>
          ) : null}

          <div className="sim-meta">
            <span className="meta-pill meta-pill--soft">{t("sim.metaGp", { gp: currentGpName })}</span>
          </div>
        </div>
      </div>

      <div className="sim-card__note">{t("sim.note")}</div>
    </div>
  );
}
