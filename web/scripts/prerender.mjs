// Último passo do "npm run build": troca o marcador <!--app--> do dist/index.html pelo
// HTML da página, gerado pelo React (src/prerender.jsx, compilado em dist-ssr/).
//
// Por quê: sem isso, o formulário só aparece depois que o JavaScript carrega e empurra o
// resto da página para baixo (o Lighthouse mede isso como "layout shift"). Com o HTML
// pronto, a página aparece inteira de uma vez e o React só liga os eventos.
import fs from "node:fs";

const { render } = await import("../dist-ssr/prerender.js");
const arquivo = new URL("../dist/index.html", import.meta.url);
const html = fs.readFileSync(arquivo, "utf8");

if (!html.includes("<!--app-->")) {
  throw new Error("dist/index.html sem o marcador <!--app-->: a página não foi pré-renderizada.");
}

fs.writeFileSync(arquivo, html.replace("<!--app-->", render()));
// A versão para Node só serve para gerar o HTML: não vai para o site.
fs.rmSync(new URL("../dist-ssr", import.meta.url), { recursive: true, force: true });
console.log("dist/index.html pré-renderizado.");
