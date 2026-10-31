import { useSyncExternalStore } from "react";

// Tema claro ou escuro, como no portfólio. O public/theme.js já aplicou o tema salvo no
// <html> antes de a página aparecer; aqui o botão só lê e troca.
//
// useSyncExternalStore porque o HTML vem pré-renderizado sem saber o tema (no build não
// há navegador): o React desenha primeiro como "escuro", igual ao HTML, e logo depois
// usa o tema de verdade, sem erro de hidratação.
const ouvintes = new Set();

function assinar(ouvinte) {
  ouvintes.add(ouvinte);
  return () => ouvintes.delete(ouvinte);
}

function temaAtual() {
  return document.documentElement.dataset.theme === "light" ? "light" : "dark";
}

export function useTema() {
  const tema = useSyncExternalStore(assinar, temaAtual, () => "dark");

  function alternar() {
    const novo = tema === "dark" ? "light" : "dark";
    document.documentElement.dataset.theme = novo;
    try {
      localStorage.setItem("theme", novo);
    } catch {
      // Sem localStorage (ex.: navegação privada) o tema vale só para esta visita.
    }
    ouvintes.forEach((ouvinte) => ouvinte());
  }

  return { tema, alternar };
}
