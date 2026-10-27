// Mostra as notas do Lighthouse como anotações no GitHub (aparecem no PR).
// Lê o resumo gerado pelo `lhci autorun` em lighthouse-report/manifest.json e,
// do relatório completo da execução representativa, lista as auditorias que
// não tiraram nota máxima (é por elas que se chega aos 100).
import fs from "node:fs";
import path from "node:path";

const reportDir = "lighthouse-report";
const runs = JSON.parse(fs.readFileSync(path.join(reportDir, "manifest.json"), "utf8"));
const representative = runs.find((run) => run.isRepresentativeRun) ?? runs[0];
const scores = Object.entries(representative.summary)
  .map(([category, score]) => `${category}: ${Math.round(score * 100)}`)
  .join(", ");

console.log(`::notice title=Lighthouse (${representative.url})::${scores}`);

const report = JSON.parse(fs.readFileSync(representative.jsonPath, "utf8"));
const metricIds = [
  "first-contentful-paint",
  "largest-contentful-paint",
  "total-blocking-time",
  "cumulative-layout-shift",
  "speed-index",
];
const metrics = metricIds
  .map((id) => `${id}: ${report.audits[id]?.displayValue ?? "?"}`)
  .join(", ");
console.log(`::notice title=Lighthouse (métricas)::${metrics}`);

// Auditorias informativas ("manual", "notApplicable"...) não contam para a nota.
const scoredModes = new Set(["binary", "numeric", "metricSavings"]);
const belowMax = Object.values(report.audits)
  .filter((audit) => scoredModes.has(audit.scoreDisplayMode))
  .filter((audit) => audit.score !== null && audit.score < 1)
  .map((audit) => [audit.id, audit.score, audit.displayValue].filter(Boolean).join(" "));

if (belowMax.length > 0) {
  console.log(`::warning title=Lighthouse (abaixo da nota máxima)::${belowMax.join("; ")}`);
}

// Detalhes que explicam o tempo de carregamento: o que bloqueia a primeira pintura,
// qual é o maior elemento da tela (LCP) e quanto pesa cada arquivo.
const blocking = report.audits["render-blocking-resources"]?.details?.items ?? [];
const lcpElement = report.audits["largest-contentful-paint-element"]?.details?.items?.[0];
const requests = report.audits["network-requests"]?.details?.items ?? [];
const details = [
  `bloqueiam a pintura: ${blocking.map((item) => `${item.url} (${item.wastedMs} ms)`).join(", ") || "nada"}`,
  `LCP: ${JSON.stringify(lcpElement?.items?.[0]?.node?.snippet ?? lcpElement?.node?.snippet ?? "?")}`,
  `arquivos: ${requests
    .map(
      (item) =>
        `${item.url.replace(/^https?:\/\/[^/]+/, "")} ${Math.round(item.transferSize / 1024)} KB`,
    )
    .join(", ")}`,
];
console.log(`::notice title=Lighthouse (detalhes)::${details.join(" | ")}`);
