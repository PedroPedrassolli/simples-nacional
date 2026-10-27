import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
// As fontes vêm junto com o build (sem Google Fonts): a CSP só permite arquivos
// do próprio site, e a página não depende de outro servidor para abrir.
import "@fontsource-variable/geist";
import "@fontsource-variable/geist-mono";
import "./estilo.css";
import Calculadora from "./Calculadora.jsx";

// O título, a explicação e os avisos já vêm prontos no index.html (aparecem antes do
// JavaScript carregar). O React cuida só da parte que muda: o formulário e o resultado.
createRoot(document.getElementById("calculadora")).render(
  <StrictMode>
    <Calculadora />
  </StrictMode>,
);
