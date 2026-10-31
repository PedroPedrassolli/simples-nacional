import { StrictMode } from "react";
import { createRoot, hydrateRoot } from "react-dom/client";
// As fontes (Geist) ficam em public/fontes/ e são declaradas no estilo.css.
import "./estilo.css";
import App from "./App.jsx";

const raiz = document.getElementById("root");
const pagina = (
  <StrictMode>
    <App />
  </StrictMode>
);

// No site publicado, o HTML da página já vem pronto (pré-renderizado no build): o React
// só "hidrata", ligando os eventos sem redesenhar nada. Em "npm run dev" não há
// pré-renderização, e o React desenha a página do zero.
if (raiz.firstElementChild) {
  hydrateRoot(raiz, pagina);
} else {
  createRoot(raiz).render(pagina);
}
