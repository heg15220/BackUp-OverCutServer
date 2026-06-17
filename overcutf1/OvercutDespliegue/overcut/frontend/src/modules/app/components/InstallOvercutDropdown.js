import React, { useEffect, useState } from "react";

const isIos = () => /iphone|ipad|ipod/i.test(window.navigator.userAgent);
const isStandalone = () =>
  window.matchMedia?.("(display-mode: standalone)")?.matches ||
  window.navigator.standalone === true;

const InstallOvercutDropdown = () => {
  const [open, setOpen] = useState(false);
  const [deferredPrompt, setDeferredPrompt] = useState(null);
  const [canInstall, setCanInstall] = useState(false);

  useEffect(() => {
    const handler = (e) => {
      e.preventDefault();
      setDeferredPrompt(e);
      setCanInstall(true);
    };

    window.addEventListener("beforeinstallprompt", handler);
    return () => window.removeEventListener("beforeinstallprompt", handler);
  }, []);

  const handleInstall = async () => {
    if (!deferredPrompt) return;
    deferredPrompt.prompt();
    await deferredPrompt.userChoice;
    setDeferredPrompt(null);
    setCanInstall(false);
    setOpen(false);
  };

  if (isStandalone()) return null;

  return (
    <div style={{ position: "relative", display: "inline-block" }}>
      <button
        className="btn btn-outline-light"
        onClick={() => setOpen((v) => !v)}
      >
        Instalar / Acceso directo
      </button>

      {open && (
        <div
          style={{
            position: "absolute",
            left: 0,
            marginTop: 8,
            minWidth: 300,
            background: "#111",
            border: "1px solid rgba(255,255,255,0.15)",
            borderRadius: 10,
            padding: 12,
            zIndex: 9999
          }}
        >
          {canInstall ? (
            <button className="btn btn-primary w-100" onClick={handleInstall}>
              Instalar OverCut
            </button>
          ) : (
            <div style={{ color: "white", fontSize: 14, lineHeight: 1.35 }}>
              {isIos() ? (
                <>
                  <b>iPhone / iPad:</b><br />
                  Pulsa <b>Compartir</b> → <b>Añadir a pantalla de inicio</b>.
                </>
              ) : (
                <>
                  <b>No disponible automáticamente aquí.</b><br />
                  En Chrome/Edge abre el menú del navegador y busca <b>“Instalar OverCut”</b>.
                </>
              )}
            </div>
          )}
        </div>
      )}
    </div>
  );
};

export default InstallOvercutDropdown;
