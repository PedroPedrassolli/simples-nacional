// Aplica o tema salvo antes de a página aparecer, para não "piscar" no tema errado.
// Mesmo padrão do portfólio (pedrassolli.vercel.app): escuro por padrão, claro se a
// pessoa escolheu. Fica num arquivo, e não dentro do HTML, porque a Content-Security-
// Policy do vercel.json só deixa rodar scripts do próprio site.
(function () {
  let theme = null;
  try {
    theme = localStorage.getItem("theme");
  } catch {
    // Navegação privada pode bloquear o localStorage; seguimos com o tema escuro.
  }
  if (theme !== "light" && theme !== "dark") {
    theme = "dark";
  }
  document.documentElement.dataset.theme = theme;
})();
