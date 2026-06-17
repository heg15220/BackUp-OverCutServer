import React from 'react';
import './Footer.css';

const Footer = () => {
  const lang = navigator.language.startsWith('es') ? 'es' : 'en';

  const text = lang === 'es'
    ? `© ${new Date().getFullYear()} OverCutHub. Un servicio de análisis de datos.`
    : `© ${new Date().getFullYear()} OverCutHub. A data analysis service.`;

  return (
    <footer className="f1hub-footer">
      <p>{text}</p>
    </footer>
  );
};

export default Footer;
