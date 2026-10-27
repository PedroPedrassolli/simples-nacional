import { StrictMode } from "react";
import { renderToString } from "react-dom/server";
import App from "./App.jsx";

// Usado só no build (scripts/prerender.mjs): gera o HTML da página para ir dentro do
// index.html. Precisa ser igual ao que o main.jsx desenha, para o React só hidratar.
export function render() {
  return renderToString(
    <StrictMode>
      <App />
    </StrictMode>,
  );
}
