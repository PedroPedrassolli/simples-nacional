import { test, expect } from "@playwright/test";
import AxeBuilder from "@axe-core/playwright";

// Verificação automática de acessibilidade com o axe (regras WCAG 2.1 A e AA).
// Falha só com problemas "serious" ou "critical" e lista cada um com o elemento afetado.
async function problemasGraves(page) {
  const resultado = await new AxeBuilder({ page })
    .withTags(["wcag2a", "wcag2aa", "wcag21a", "wcag21aa"])
    .analyze();

  return resultado.violations
    .filter((violacao) => ["serious", "critical"].includes(violacao.impact))
    .map((violacao) => {
      const alvos = violacao.nodes.map((node) => node.target.join(" ")).join(" | ");
      return `${violacao.id}: ${violacao.help} → ${alvos}`;
    });
}

for (const tema of ["light", "dark"]) {
  test(`não tem problemas graves de acessibilidade (tema ${tema})`, async ({ page }) => {
    await page.emulateMedia({ colorScheme: tema });
    await page.goto("/");
    await expect(page.getByRole("heading", { level: 1 })).toBeVisible();

    expect(await problemasGraves(page)).toEqual([]);
  });
}

test("mostra o aviso de estimativa educativa", async ({ page }) => {
  await page.goto("/");

  await expect(page.getByText("não substitui o PGDAS-D nem um contador")).toBeVisible();
});

test.describe("num celular de 320 px", () => {
  test.use({ viewport: { width: 320, height: 640 } });

  test("não tem rolagem lateral", async ({ page }) => {
    await page.goto("/");
    await expect(page.getByRole("heading", { level: 1 })).toBeVisible();

    const larguras = await page.evaluate(() => ({
      conteudo: document.documentElement.scrollWidth,
      tela: document.documentElement.clientWidth,
    }));
    expect(larguras.conteudo).toBeLessThanOrEqual(larguras.tela);
  });
});
