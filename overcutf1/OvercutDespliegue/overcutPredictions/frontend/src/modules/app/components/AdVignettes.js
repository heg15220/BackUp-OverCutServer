import React from "react";
import { ENABLE_MONETIZATION_PREVIEW } from "./monetizationGate";
import "./AdVignettes.css";

const AdVignettes = () => {
  if (!ENABLE_MONETIZATION_PREVIEW) {
    return null;
  }

  return (
    <div className="ocp-ad-vignettes" aria-label="Publicidad">
      <aside className="ocp-ad-rail ocp-ad-rail--left" aria-hidden="true">
        <span className="ocp-ad-slot ocp-ad-slot--rail" />
        <span className="ocp-ad-slot ocp-ad-slot--rail" />
      </aside>
      <aside className="ocp-ad-rail ocp-ad-rail--right" aria-hidden="true">
        <span className="ocp-ad-slot ocp-ad-slot--rail" />
        <span className="ocp-ad-slot ocp-ad-slot--rail" />
      </aside>
      <div className="ocp-ad-bottom" aria-hidden="true">
        <span className="ocp-ad-slot ocp-ad-slot--bottom" />
      </div>
    </div>
  );
};

export default AdVignettes;
