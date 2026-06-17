import React, { useCallback, useEffect, useMemo, useRef, useState } from "react";
import AdPreviewCard from "./AdPreviewCard";
import {
  DESKTOP_AD_VIGNETTE_SLOTS,
  MOBILE_BOTTOM_AD_VIGNETTE_SLOT,
  TABLET_AD_VIGNETTE_SLOTS,
} from "./AdVignetteConfig";
import "./AdVignetteLayout.css";

const resolveLocale = () => {
  const lang = navigator.language || navigator.userLanguage || "es";
  return lang.toLowerCase().startsWith("es") ? "es" : "en";
};

const splitBySide = (slots) => ({
  left: slots.filter((slot) => slot.side === "left"),
  right: slots.filter((slot) => slot.side === "right"),
});

const RAIL_WIDTH = 184;
const RAIL_INSET = 16;
const MIN_CONTENT_GAP = 24;
const MIN_SIDE_SPACE = RAIL_WIDTH + RAIL_INSET + MIN_CONTENT_GAP;

const isPortraitViewport = () =>
  window.matchMedia && window.matchMedia("(orientation: portrait)").matches;

const isVisibleContentElement = (element) => {
  if (!(element instanceof HTMLElement)) return false;
  if (element.closest(".overcut-ad-column, .overcut-ad-layout__mobile-bottom")) return false;

  const rect = element.getBoundingClientRect();
  if (rect.width < 24 || rect.height < 24) return false;

  const styles = window.getComputedStyle(element);
  if (styles.display === "none" || styles.visibility === "hidden" || Number(styles.opacity) === 0) {
    return false;
  }

  const isFullscreenShell =
    rect.width >= window.innerWidth * 0.96 &&
    rect.height >= window.innerHeight * 0.65;
  const isDecorativeLayer =
    styles.pointerEvents === "none" ||
    element.className.toString().toLowerCase().includes("background") ||
    element.className.toString().toLowerCase().includes("overlay");

  return !(isFullscreenShell || isDecorativeLayer);
};

const getInteractiveContentRect = (contentElement) => {
  const candidates = Array.from(contentElement.querySelectorAll("*")).filter(isVisibleContentElement);

  if (candidates.length === 0) {
    return contentElement.firstElementChild?.getBoundingClientRect() || contentElement.getBoundingClientRect();
  }

  return candidates.reduce((bounds, element) => {
    const rect = element.getBoundingClientRect();
    return {
      left: Math.min(bounds.left, rect.left),
      right: Math.max(bounds.right, rect.right),
      top: Math.min(bounds.top, rect.top),
      bottom: Math.max(bounds.bottom, rect.bottom),
    };
  }, candidates[0].getBoundingClientRect());
};

const AdColumn = ({ side, desktopSlots, tabletSlots, locale }) => (
  <aside className={`overcut-ad-column overcut-ad-column--${side}`} aria-label="Publicidad">
    <div className="overcut-ad-column__desktop">
      {desktopSlots.map((slot) => (
        <AdPreviewCard key={slot.id} slot={slot} locale={locale} className="overcut-ad-card--rail" />
      ))}
    </div>
    <div className="overcut-ad-column__tablet">
      {tabletSlots.map((slot) => (
        <AdPreviewCard key={slot.id} slot={slot} locale={locale} className="overcut-ad-card--tablet" />
      ))}
    </div>
  </aside>
);

const AdVignetteLayout = ({ children, page = "games", placement = "auto" }) => {
  const locale = useMemo(resolveLocale, []);
  const desktopSlots = useMemo(() => splitBySide(DESKTOP_AD_VIGNETTE_SLOTS), []);
  const tabletSlots = useMemo(() => splitBySide(TABLET_AD_VIGNETTE_SLOTS), []);
  const contentRef = useRef(null);
  const [resolvedPlacement, setResolvedPlacement] = useState(placement === "bottom" ? "bottom" : "side");

  const resolvePlacement = useCallback(() => {
    if (placement === "bottom") {
      setResolvedPlacement("bottom");
      return;
    }

    if (!contentRef.current || window.innerWidth < 1200 || isPortraitViewport()) {
      setResolvedPlacement("bottom");
      return;
    }

    const contentRect = getInteractiveContentRect(contentRef.current);
    const leftSpace = Math.max(0, contentRect.left);
    const rightSpace = Math.max(0, window.innerWidth - contentRect.right);
    const hasLateralSpace = leftSpace >= MIN_SIDE_SPACE && rightSpace >= MIN_SIDE_SPACE;

    setResolvedPlacement(hasLateralSpace ? "side" : "bottom");
  }, [placement]);

  useEffect(() => {
    let frame = null;
    const scheduleResolve = () => {
      if (frame) window.cancelAnimationFrame(frame);
      frame = window.requestAnimationFrame(resolvePlacement);
    };

    scheduleResolve();
    window.addEventListener("resize", scheduleResolve);
    window.addEventListener("orientationchange", scheduleResolve);

    const observer = typeof ResizeObserver !== "undefined"
      ? new ResizeObserver(scheduleResolve)
      : null;

    if (observer && contentRef.current) {
      observer.observe(contentRef.current);
      Array.from(contentRef.current.children).forEach((child) => observer.observe(child));
    }

    const mutationObserver = new MutationObserver(scheduleResolve);
    if (contentRef.current) {
      mutationObserver.observe(contentRef.current, {
        childList: true,
        subtree: true,
        attributes: true,
        attributeFilter: ["class", "style"],
      });
    }

    return () => {
      if (frame) window.cancelAnimationFrame(frame);
      window.removeEventListener("resize", scheduleResolve);
      window.removeEventListener("orientationchange", scheduleResolve);
      if (observer) observer.disconnect();
      mutationObserver.disconnect();
    };
  }, [resolvePlacement, children]);

  return (
    <section
      className={`overcut-ad-layout overcut-ad-layout--${page} overcut-ad-layout--${resolvedPlacement}`}
      data-requested-placement={placement}
      data-resolved-placement={resolvedPlacement}
    >
      <AdColumn
        side="left"
        desktopSlots={desktopSlots.left}
        tabletSlots={tabletSlots.left}
        locale={locale}
      />
      <main className="overcut-ad-layout__content" ref={contentRef}>{children}</main>
      <AdColumn
        side="right"
        desktopSlots={desktopSlots.right}
        tabletSlots={tabletSlots.right}
        locale={locale}
      />
      <div className="overcut-ad-layout__mobile-bottom" aria-label="Publicidad">
        <AdPreviewCard
          slot={MOBILE_BOTTOM_AD_VIGNETTE_SLOT}
          locale={locale}
          className="overcut-ad-card--mobile-bottom"
        />
      </div>
    </section>
  );
};

export default AdVignetteLayout;
