#!/usr/bin/env node
/**
 * maestri-software-factory — instalador/atualizador para `npx`.
 *
 *   npx maestri-software-factory --target kiro|claude [opções]            # instala (padrão)
 *   npx maestri-software-factory update  --target kiro|claude [opções]    # atualiza (remove órfãos)
 *   npx maestri-software-factory uninstall --target kiro|claude [opções]  # remove o que foi instalado
 *   npx maestri-software-factory --version
 *
 * Opções: --global (em ~/.kiro|~/.claude) · --dest <dir> (padrão: cwd) · --dry-run
 *
 * O que é "gerenciado" (e só isso é tocado): as skills factory* e tlc-* e os agentes factory-*.
 * NUNCA toca em AGENTS.md/CLAUDE.md, nem em outras skills/agentes seus.
 * Registra um manifesto em <base>/.factory-manifest.json com a versão e a lista de arquivos,
 * para que `update` remova arquivos que saíram de versões novas e `uninstall` limpe tudo.
 */
"use strict";
const fs = require("fs");
const os = require("os");
const path = require("path");

const PKG_ROOT = path.resolve(__dirname, "..");
const PKG = JSON.parse(fs.readFileSync(path.join(PKG_ROOT, "package.json"), "utf8"));
const MANIFEST = ".factory-manifest.json";

const HELP = `
maestri-software-factory v${PKG.version} — instala/atualiza as skills + agentes da fábrica.

  npx maestri-software-factory --target kiro|claude [opções]            instala (padrão)
  npx maestri-software-factory update   --target kiro|claude [opções]   atualiza (remove órfãos)
  npx maestri-software-factory uninstall --target kiro|claude [opções]  remove o instalado
  npx maestri-software-factory --version

Opções:
  --target kiro|claude   obrigatório (exceto --version)
  --global               em ~/.kiro ou ~/.claude (todos os projetos)
  --dest <dir>           raiz do projeto alvo (padrão: diretório atual)
  --dry-run              só mostra o que faria

Nunca toca em AGENTS.md/CLAUDE.md nem em skills/agentes que não sejam da fábrica.
`;

function parseArgs(argv) {
  const o = { cmd: "install", target: "", global: false, dest: process.cwd(), dryRun: false, help: false, version: false };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === "install" || a === "update" || a === "uninstall") o.cmd = a;
    else if (a === "--target") o.target = argv[++i] || "";
    else if (a === "--global") o.global = true;
    else if (a === "--dest") o.dest = argv[++i] || o.dest;
    else if (a === "--dry-run") o.dryRun = true;
    else if (a === "--version" || a === "-V") o.version = true;
    else if (a === "-h" || a === "--help") o.help = true;
    else if (a === "--") { /* separador do npx */ }
    else { console.error("argumento desconhecido: " + a); process.exit(2); }
  }
  return o;
}

const walk = (dir, out = []) => {
  for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, e.name);
    if (e.isDirectory()) walk(p, out); else out.push(p);
  }
  return out;
};

// lista {src, rel} dos arquivos que o pacote entrega, rel = caminho relativo à base (.kiro/.claude)
function shipped(target) {
  const files = [];
  const sroot = path.join(PKG_ROOT, "skills");
  for (const f of walk(sroot)) files.push({ src: f, rel: path.join("skills", path.relative(sroot, f)) });
  if (target === "kiro") {
    const ad = path.join(PKG_ROOT, "agents", "kiro");
    for (const f of fs.readdirSync(ad)) if (f.endsWith(".json")) files.push({ src: path.join(ad, f), rel: path.join("agents", f) });
    const pd = path.join(ad, "prompts");
    for (const f of fs.readdirSync(pd)) if (f.endsWith(".md")) files.push({ src: path.join(pd, f), rel: path.join("agents", "prompts", f) });
  } else {
    const ad = path.join(PKG_ROOT, "agents", "claude");
    for (const f of fs.readdirSync(ad)) if (f.endsWith(".md")) files.push({ src: path.join(ad, f), rel: path.join("agents", f) });
  }
  return files;
}

const readManifest = (base) => {
  try { return JSON.parse(fs.readFileSync(path.join(base, MANIFEST), "utf8")); } catch { return null; }
};

function rmFile(p, dry) {
  if (dry) { console.log("DRY  rm " + p); return; }
  try { fs.rmSync(p, { force: true }); } catch {}
}

function pruneEmpty(root, dry) {
  if (!fs.existsSync(root)) return;
  for (const e of fs.readdirSync(root, { withFileTypes: true })) {
    if (e.isDirectory()) pruneEmpty(path.join(root, e.name), dry);
  }
  try {
    if (fs.readdirSync(root).length === 0) { if (dry) console.log("DRY  rmdir " + root); else fs.rmdirSync(root); }
  } catch {}
}

function copyManaged(base, target, dry) {
  const files = shipped(target);
  const rels = [];
  for (const { src, rel } of files) {
    const dst = path.join(base, rel);
    rels.push(rel);
    if (dry) { console.log("DRY  write " + dst); continue; }
    fs.mkdirSync(path.dirname(dst), { recursive: true });
    const isSkillText = rel.startsWith("skills" + path.sep) && /\.(md|json|py|txt)$/.test(rel);
    if (target === "claude" && isSkillText) {
      const txt = fs.readFileSync(src, "utf8");
      fs.writeFileSync(dst, txt.includes(".kiro/") ? txt.split(".kiro/").join(".claude/") : txt);
    } else {
      fs.copyFileSync(src, dst);
    }
  }
  if (!dry) {
    const manifest = { name: PKG.name, version: PKG.version, target, installedAt: new Date().toISOString(), files: rels };
    fs.writeFileSync(path.join(base, MANIFEST), JSON.stringify(manifest, null, 2) + "\n");
  }
  return rels;
}

function main() {
  const o = parseArgs(process.argv.slice(2));
  if (o.version) { console.log(PKG.version); return; }
  if (o.help) { console.log(HELP); return; }
  if (o.target !== "kiro" && o.target !== "claude") { console.error("use --target kiro|claude\n" + HELP); process.exit(2); }

  const dot = "." + o.target;
  const base = o.global ? path.join(os.homedir(), dot) : path.join(path.resolve(o.dest), dot);
  const prev = readManifest(base);

  if (o.cmd === "uninstall") {
    if (!prev) { console.error(`Nada para remover: ${path.join(base, MANIFEST)} não existe.`); process.exit(1); }
    console.log(`Removendo Software Factory (v${prev.version}) de: ${base}`);
    for (const rel of prev.files) rmFile(path.join(base, rel), o.dryRun);
    rmFile(path.join(base, MANIFEST), o.dryRun);
    pruneEmpty(path.join(base, "skills"), o.dryRun);
    pruneEmpty(path.join(base, "agents"), o.dryRun);
    console.log(o.dryRun ? "(dry-run) nada foi removido." : "Removido. AGENTS.md/CLAUDE.md e suas outras skills/agentes não foram tocados.");
    return;
  }

  const verb = o.cmd === "update" ? "Atualizando" : "Instalando";
  console.log(`${verb} Software Factory v${PKG.version} para '${o.target}' em: ${base}` + (prev ? `  (tinha v${prev.version})` : ""));

  // update: remove arquivos da versão anterior (inclusive órfãos que saíram desta versão)
  if (o.cmd === "update" && prev) {
    const nowRels = new Set(shipped(o.target).map((x) => x.rel));
    const orphans = prev.files.filter((r) => !nowRels.has(r));
    for (const rel of prev.files) rmFile(path.join(base, rel), o.dryRun);
    if (orphans.length) console.log(`  removidos ${orphans.length} arquivo(s) que saíram desta versão.`);
  }

  copyManaged(base, o.target, o.dryRun);
  if (o.cmd === "update" && !o.dryRun) { pruneEmpty(path.join(base, "skills"), false); pruneEmpty(path.join(base, "agents"), false); }

  console.log("");
  if (prev && o.cmd === "update") console.log(`OK. v${prev.version} → v${PKG.version}.`);
  else console.log("OK.");
  console.log("Próximos passos:");
  console.log("  1) Copie AGENTS.sample.md (kiro) ou CLAUDE.sample.md (claude) para a raiz do projeto e preencha factory.* (só na 1ª vez).");
  console.log(`  2) No Maestri, rode scripts/setup-maestri-${o.target}.sh dentro de um terminal do app para criar os presets.`);
  console.log("  3) Abra o preset 'Factory Maestro' no Ground e rode /factory <feature>.");
}

main();
