#!/usr/bin/env node
/**
 * maestri-software-factory — instalador para `npx`.
 *
 * Uso:
 *   npx maestri-software-factory --target kiro   [--global] [--dest <dir>] [--dry-run]
 *   npx maestri-software-factory --target claude [--global] [--dest <dir>] [--dry-run]
 *
 * Copia:
 *   skills/*       -> <base>/skills/    (factory*, tlc-spec-lean, tlc-discover)
 *   agents/<cli>/* -> <base>/agents/    (.json+prompts p/ kiro ; .md p/ claude)
 * Para o alvo claude, reescreve caminhos ".kiro/" -> ".claude/" nos arquivos de skill.
 * <base> = <dest>/.kiro|.claude  (ou ~/.kiro|~/.claude com --global).
 */
"use strict";
const fs = require("fs");
const os = require("os");
const path = require("path");

const PKG_ROOT = path.resolve(__dirname, "..");

function parseArgs(argv) {
  const o = { target: "", global: false, dest: process.cwd(), dryRun: false, help: false };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === "--target") o.target = argv[++i] || "";
    else if (a === "--global") o.global = true;
    else if (a === "--dest") o.dest = argv[++i] || o.dest;
    else if (a === "--dry-run") o.dryRun = true;
    else if (a === "-h" || a === "--help") o.help = true;
    else if (a === "--") { /* separador do npx; ignore */ }
    else if (a === "install") {/* comando padrão, ignore */}
    else { console.error("argumento desconhecido: " + a); process.exit(2); }
  }
  return o;
}

const HELP = `
maestri-software-factory — instala skills + agentes para Kiro CLI ou Claude Code.

  npx maestri-software-factory --target kiro   [--global] [--dest <dir>] [--dry-run]
  npx maestri-software-factory --target claude [--global] [--dest <dir>] [--dry-run]

  --target kiro|claude   obrigatório. Qual CLI.
  --global               instala em ~/.kiro ou ~/.claude (todos os projetos).
  --dest <dir>           raiz do projeto alvo (padrão: diretório atual). Ignorado com --global.
  --dry-run              só mostra o que faria.
`;

function copyDir(src, dst, dry) {
  if (dry) { console.log(`DRY  copy ${src} -> ${dst}`); return; }
  fs.mkdirSync(dst, { recursive: true });
  fs.cpSync(src, dst, { recursive: true });
}

function walk(dir, out = []) {
  for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, e.name);
    if (e.isDirectory()) walk(p, out);
    else out.push(p);
  }
  return out;
}

function main() {
  const o = parseArgs(process.argv.slice(2));
  if (o.help || !o.target) { console.log(HELP); process.exit(o.help ? 0 : 2); }
  if (o.target !== "kiro" && o.target !== "claude") {
    console.error("use --target kiro|claude"); process.exit(2);
  }

  const dot = "." + o.target;                       // .kiro | .claude
  const base = o.global ? path.join(os.homedir(), dot) : path.join(path.resolve(o.dest), dot);
  const skillsDst = path.join(base, "skills");
  const agentsDst = path.join(base, "agents");

  console.log(`Instalando Software Factory para '${o.target}' em: ${base}`);

  // skills
  copyDir(path.join(PKG_ROOT, "skills"), skillsDst, o.dryRun);
  if (o.target === "claude" && !o.dryRun) {
    for (const f of walk(skillsDst)) {
      if (!/\.(md|json|py|txt)$/.test(f)) continue;
      const txt = fs.readFileSync(f, "utf8");
      if (txt.includes(".kiro/")) fs.writeFileSync(f, txt.split(".kiro/").join(".claude/"));
    }
    console.log("  (caminhos .kiro/ reescritos para .claude/ nas skills)");
  } else if (o.target === "claude") {
    console.log("DRY  reescrever .kiro/ -> .claude/ nos arquivos de skill");
  }

  // agents
  if (o.target === "kiro") {
    copyDir(path.join(PKG_ROOT, "agents", "kiro"), agentsDst, o.dryRun);
  } else {
    // só os .md dos agentes claude (sem a pasta prompts/ do kiro)
    if (o.dryRun) {
      console.log(`DRY  copy agents/claude/*.md -> ${agentsDst}`);
    } else {
      fs.mkdirSync(agentsDst, { recursive: true });
      const srcA = path.join(PKG_ROOT, "agents", "claude");
      for (const f of fs.readdirSync(srcA)) {
        if (f.endsWith(".md")) fs.copyFileSync(path.join(srcA, f), path.join(agentsDst, f));
      }
    }
  }

  console.log("");
  console.log("OK. Próximos passos:");
  console.log("  1) Copie AGENTS.sample.md (kiro) ou CLAUDE.sample.md (claude) para a raiz do projeto e preencha factory.*");
  console.log(`  2) No Maestri, rode scripts/setup-maestri-${o.target}.sh dentro de um terminal do app para criar os presets.`);
  console.log("  3) Abra o preset 'Factory Maestro' no Ground e rode /factory <feature>.");
}

main();
