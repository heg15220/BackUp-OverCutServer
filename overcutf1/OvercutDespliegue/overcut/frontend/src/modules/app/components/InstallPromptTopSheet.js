import React, { useEffect, useState } from "react";

const STORAGE_KEY = "overcut_pwa_install_dismissed_until";

const isStandalone = () =>
  window.matchMedia?.("(display-mode: standalone)")?.matches ||
  window.navigator.standalone === true;

const getDismissedUntil = () => {
  const v = localStorage.getItem(STORAGE_KEY);
  const n = v ? parseInt(v, 10) : 0;
  return Number.isFinite(n) ? n : 0;
};

const setDismissedForDays = (days) => {
  const until = Date.now() + days * 24 * 60 * 60 * 1000;
  localStorage.setItem(STORAGE_KEY, String(until));
};

const InstallPromptTopSheet = () => {
  const [deferredPrompt, setDeferredPrompt] = useState(null);
  const [visible, setVisible] = useState(false);

  useEffect(() => {
    // Si ya está instalada, no mostramos nada
    if (isStandalone()) return;

    // Si el usuario lo cerró recientemente, no mostramos nada
    const dismissedUntil = getDismissedUntil();
    if (dismissedUntil && dismissedUntil > Date.now()) return;

    const handler = (e) => {
      // SOLO navegadores que soportan instalación disparan este evento
      e.preventDefault();
      setDeferredPrompt(e);
      setVisible(true);
    };

    window.addEventListener("beforeinstallprompt", handler);

    // Si se instala, ocultar
    const installedHandler = () => {
      setVisible(false);
      setDeferredPrompt(null);
    };
    window.addEventListener("appinstalled", installedHandler);

    return () => {
      window.removeEventListener("beforeinstallprompt", handler);
      window.removeEventListener("appinstalled", installedHandler);
    };
  }, []);

  const close = () => {
    // No volver a mostrar en 7 días (ajusta a tu gusto)
    setDismissedForDays(7);
    setVisible(false);
  };

  const install = async () => {
    if (!deferredPrompt) return;
    deferredPrompt.prompt();
    await deferredPrompt.userChoice; // accepted / dismissed
    setDeferredPrompt(null);
    setVisible(false);
  };

  // ✅ Solo aparece si el navegador disparó beforeinstallprompt
  if (!visible || !deferredPrompt) return null;

  return (
    <div className="pwa-top-sheet" role="dialog" aria-label="Install OverCut">
      <div className="pwa-top-sheet-inner">
        <div className="pwa-top-sheet-left">
          <img
            className="pwa-top-sheet-icon"
            src="/icons/overcut-192.png"
            alt="OverCut"
          />
          <div className="pwa-top-sheet-text">
            <div className="pwa-top-sheet-title">Install OverCut</div>
            <div className="pwa-top-sheet-subtitle">
              Download direct access on the device.
            </div>
          </div>
        </div>

        <div className="pwa-top-sheet-actions">
          <button className="btn btn-primary" onClick={install}>
            Install
          </button>
          <button className="btn btn-outline-light" onClick={close}>
            Cancel
          </button>
        </div>
      </div>
    </div>
  );
};

export default InstallPromptTopSheet;
