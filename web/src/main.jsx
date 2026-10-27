import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
// As fontes vêm junto com o build (sem Google Fonts): a CSP só permite arquivos
// do próprio site, e a página não depende de outro servidor para abrir.
import "@fontsource-variable/geist";
import "@fontsource-variable/geist-mono";
import "./estilo.css";
import App from "./App.jsx";

createRoot(document.getElementById("root")).render(
  <StrictMode>
    <App />
  </StrictMode>,
);
