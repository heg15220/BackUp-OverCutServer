import React from "react";
import { useLocation } from "react-router-dom";

// count.js ya registra la carga inicial de la página, así que aquí solo se
// reportan las navegaciones que BrowserRouter hace después, sin recargar.
const GoatCounterTracker = () => {
  const location = useLocation();
  const isInitialLoad = React.useRef(true);

  React.useEffect(() => {
    if (isInitialLoad.current) {
      isInitialLoad.current = false;
      return;
    }

    if (!window.goatcounter || typeof window.goatcounter.count !== "function") {
      return;
    }

    // window.location incluye el basename; location.pathname de react-router no.
    window.goatcounter.count({
      path: window.location.pathname + window.location.search,
      title: document.title
    });
  }, [location.pathname, location.search]);

  return null;
};

export default GoatCounterTracker;
