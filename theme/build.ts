import { mkdir, readFile, rename, writeFile } from "node:fs/promises";
import { stripTypeScriptTypes } from "node:module";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { channels, checkPalette, contrast, deriveTiers, readable, toOklch, type TierInputs } from "./derive.ts";
import { palettes } from "./palette.ts";

const root = fileURLToPath(new URL("../", import.meta.url));
const neovimTemplate = await readFile(new URL("./templates/neovim.lua", import.meta.url), "utf8");
const ghosttyTemplate = await readFile(new URL("./templates/ghostty", import.meta.url), "utf8");
const fishTemplate = await readFile(new URL("./templates/fish.theme", import.meta.url), "utf8");
const herdrTemplate = await readFile(new URL("./templates/herdr.toml", import.meta.url), "utf8");
const piTemplate = await readFile(new URL("./templates/pi.json", import.meta.url), "utf8");
const modes = ["dark", "light"] as const;
const expectedKeys = Object.keys(palettes.dark).sort().join(",");
const herdrThemeStart = "# BEGIN generated Herdr theme — edit theme/palette.ts";
const herdrThemeEnd = "# END generated Herdr theme";
const textContrast = 4.5;
const nonTextContrast = 3;

function kebabPalette(palette: Record<string, string>): Record<string, string> {
  return Object.fromEntries(Object.entries(palette).map(([name, color]) => [kebab(name), color]));
}

function pascal(name: string): string {
  return name
    .split("-")
    .map((part) => part[0].toUpperCase() + part.slice(1))
    .join("");
}

function validate(mode: (typeof modes)[number], palette: Record<string, string>): void {
  if (Object.keys(palette).sort().join(",") !== expectedKeys) {
    throw new Error(`${mode} palette does not have the same tokens as dark`);
  }
  const problems = checkPalette(mode, kebabPalette(palette));
  if (problems.length > 0) throw new Error(problems.map((problem) => `${mode}.${problem}`).join("\n"));
}

function tiers(mode: (typeof modes)[number], palette: Record<string, string>): Record<string, string> {
  const derived = deriveTiers(mode, kebabPalette(palette) as TierInputs);
  return Object.fromEntries(Object.entries(derived).map(([name, color]) => [pascal(name), color]));
}

for (const mode of modes) validate(mode, palettes[mode]);
const tiersByMode = { dark: tiers("dark", palettes.dark), light: tiers("light", palettes.light) };

const herdrConfigPath = join(root, "home", ".config", "herdr", "config.toml");
const herdrConfig = await readFile(herdrConfigPath, "utf8");
const start = herdrConfig.indexOf(herdrThemeStart);
const end = herdrConfig.indexOf(herdrThemeEnd, start);
if (start < 0 || end < 0) throw new Error("generated Herdr theme markers are missing");
const herdrHeader = '[theme]\nname = "terminal"\nauto_switch = true\ndark_name = "terminal"\nlight_name = "terminal"';
const generatedHerdrTheme = [
  herdrHeader,
  render(herdrTemplate, { ...palettes.dark, Mode: "dark" }).trimEnd(),
  render(herdrTemplate, { ...palettes.light, Mode: "light" }).trimEnd(),
].join("\n\n");
await writeAtomic(
  herdrConfigPath,
  `${herdrConfig.slice(0, start)}${herdrThemeStart}\n${generatedHerdrTheme}\n${herdrConfig.slice(end)}`,
);
console.log(`generated ${herdrConfigPath.slice(root.length)}`);

async function writeAtomic(path: string, content: string): Promise<void> {
  await mkdir(dirname(path), { recursive: true });
  const temporary = `${path}.tmp`;
  await writeFile(temporary, content);
  await rename(temporary, path);
}

function render(template: string, values: Record<string, string>): string {
  const output = template.replace(/{{(\w+)}}/g, (_, name: string) => {
    if (!(name in values)) throw new Error(`unknown template token: ${name}`);
    return values[name];
  });
  if (output.includes("{{")) throw new Error("unresolved template token");
  return output;
}

const xtermLevels = [0, 95, 135, 175, 215, 255];

function rexColor(hex: string) {
  const [red, green, blue] = channels(hex).map((byte) => byte / 255);
  return { red, green, blue, alpha: 1, colorSpace: "srgb" };
}

function xtermColor(index: number): string {
  const channels =
    index < 232
      ? [Math.floor((index - 16) / 36), Math.floor((index - 16) / 6) % 6, (index - 16) % 6].map((level) => xtermLevels[level])
      : Array(3).fill(8 + 10 * (index - 232));
  return `#${channels.map((channel) => channel.toString(16).padStart(2, "0")).join("")}`;
}

function rexTheme(name: string, mode: (typeof modes)[number], ghostty: string): string {
  const settings = new Map<string, string>();
  const ansi: string[] = [];
  for (const line of ghostty.trim().split("\n")) {
    const [key, value] = line.split(" = ");
    if (key === "palette") {
      const [index, color] = value.split("=");
      ansi[Number(index)] = color;
    } else {
      settings.set(key, value);
    }
  }
  if (ansi.filter(Boolean).length !== 16) throw new Error(`${name} does not set all 16 ANSI colors`);
  const color = (key: string) => {
    const value = settings.get(key);
    if (!value) throw new Error(`${name} does not set ${key}`);
    return rexColor(value);
  };
  const palette = {
    background: color("background"),
    foreground: color("foreground"),
    cursor: color("cursor-color"),
    cursorText: color("cursor-text"),
    selectionBackground: color("selection-background"),
    selectionForeground: color("selection-foreground"),
    ansi: ansi.map(rexColor),
    paletteBase: Object.fromEntries(Array.from({ length: 240 }, (_, offset) => [16 + offset, rexColor(xtermColor(16 + offset))])),
    paletteOverrides: {},
    paletteGenerate: false,
    paletteHarmonious: false,
  };
  return `${JSON.stringify({ name, appearance: mode, palette }, null, 2)}\n`;
}

for (const mode of modes) {
  const palette: Record<string, string> = palettes[mode];
  const values = {
    ...palette,
    ...tiersByMode[mode],
    Name: `gg-${mode}`,
    Background: mode,
    AnsiBlack: mode === "dark" ? palette.BG : palette.FGDim,
    BrightBlack: palette.Overlay,
    BrightWhite: palette.FG,
  };
  const fishValues = Object.fromEntries(
    Object.entries(values).map(([name, value]) => [name, value.replace(/^#/, "")]),
  );
  const ghostty = render(ghosttyTemplate, values);
  const outputs = [
    [join(root, "home", ".pi", "agent", "themes", `gg-${mode}.json`), render(piTemplate, values)],
    [join(root, "home", ".config", "nvim", "colors", `gg-${mode}.lua`), render(neovimTemplate, values)],
    [join(root, "home", ".config", "ghostty", "themes", `gg-${mode}`), ghostty],
    [join(root, "home", ".config", "fish", "themes", `gg-${mode}.theme`), render(fishTemplate, fishValues)],
    [join(root, "theme", "rex", `gg-${mode}.json`), rexTheme(`gg-${mode}`, mode, ghostty)],
  ];

  for (const [destination, output] of outputs) {
    await writeAtomic(destination, output);
    console.log(`generated ${destination.slice(root.length)}`);
  }
}

const webStatus = { destructive: "Red", success: "Green", warning: "Orange", info: "Cyan" } as const;
const webCharts = ["Blue", "Green", "Orange", "Magenta", "Cyan"] as const;
const webRadius = "0.5rem";
const deprecatedPre020Aliases = {
  "gg-diff-add-bg": "tint-green",
  "gg-diff-delete-bg": "tint-red",
  "gg-diff-change-bg": "tint-blue",
  "gg-search-bg": "tint-yellow",
  "gg-visual-bg": "selection-bg",
} as const;
function webSlots(mode: (typeof modes)[number], palette: Record<string, string>): Record<string, string> {
  const tier = tiersByMode[mode];
  const readableForegroundOn = (slot: string, fill: string): string => {
    const color = contrast(palette.BG, fill) > contrast(palette.FG, fill) ? palette.BG : palette.FG;
    const ratio = contrast(color, fill);
    if (ratio < textContrast) {
      throw new Error(`${mode}.${slot}-foreground contrast is ${ratio.toFixed(2)}; need ${textContrast}`);
    }
    return color;
  };
  const slots: Record<string, string> = { background: palette.BG, foreground: palette.FG };
  for (const slot of ["card", "popover"]) {
    slots[slot] = palette.Surface;
    slots[`${slot}-foreground`] = palette.FG;
  }
  slots.primary = palette.Accent;
  slots["primary-foreground"] = readableForegroundOn("primary", palette.Accent);
  slots.secondary = palette.Surface;
  slots["secondary-foreground"] = palette.FG;
  slots.muted = palette.Surface;
  slots["muted-foreground"] = palette.FGDim;
  slots.accent = palette.Surface;
  slots["accent-foreground"] = palette.FG;
  for (const [slot, hue] of Object.entries(webStatus)) {
    slots[slot] = tier[`Soft${hue}`];
    slots[`${slot}-foreground`] = readableForegroundOn(slot, slots[slot]);
  }
  const alpha = mode === "dark" ? [14, 22] : [12, 18];
  slots.border = `color-mix(in oklab, var(--foreground) ${alpha[0]}%, transparent)`;
  slots.input = `color-mix(in oklab, var(--foreground) ${alpha[1]}%, transparent)`;
  slots.ring = palette.Accent;
  slots.link = readable(mode, `${mode}.link`, palette.Accent, [palette.BG, palette.Surface], textContrast);
  slots["link-visited"] = readable(mode, `${mode}.link-visited`, tier.QuietAccent, [palette.BG, palette.Surface], textContrast);
  slots.selection = palette.SelectionBG;
  slots["selection-foreground"] = palette.SelectionFG;
  webCharts.forEach((hue, index) => (slots[`chart-${index + 1}`] = palette[hue]));

  for (const surface of ["BG", "Surface"]) {
    const ratio = contrast(slots.ring, palette[surface]);
    if (ratio < nonTextContrast) {
      throw new Error(`${mode}.ring/${surface} contrast is ${ratio.toFixed(2)}; need ${nonTextContrast}`);
    }
  }
  return slots;
}

function kebab(name: string): string {
  return name.replace(/([a-z])([A-Z])/g, "$1-$2").replace(/([A-Z]+)([A-Z][a-z])/g, "$1-$2").toLowerCase();
}

function oklchCss(hex: string): string {
  const [lightness, chroma, hue] = toOklch(hex);
  const degrees = ((hue * 180) / Math.PI + 360) % 360;
  return `oklch(${lightness.toFixed(4)} ${chroma.toFixed(4)} ${chroma < 0.0001 ? 0 : degrees.toFixed(2)})`;
}

function cssBlock(selector: string, mode: (typeof modes)[number], declarations: [string, string][]): string {
  const lines = declarations.map(([name, value]) => `  --${name}: ${value};`);
  return `${selector} {\n${lines.join("\n")}\n\n  color-scheme: ${mode};\n}`;
}

const webSelectors = { light: ":root", dark: ".dark" } as const;
const webModes = ["light", "dark"] as const;
const webRoot = join(root, "theme", "web");
const webPackage = JSON.parse(await readFile(join(webRoot, "package.json"), "utf8"));
const slotsByMode = { light: webSlots("light", palettes.light), dark: webSlots("dark", palettes.dark) };
const slotNames = Object.keys(slotsByMode.light);

const webOutputs: [string, string][] = [
  [
    "index.css",
    [
      "/* gg-theme — generated from theme/palette.ts. Do not edit. */",
      ...webModes.map((mode) =>
        cssBlock(webSelectors[mode], mode, [
          ...Object.entries(slotsByMode[mode]),
          ...(mode === "light" ? [["radius", webRadius] as [string, string]] : []),
        ]),
      ),
      "::selection {\n  background: var(--selection);\n  color: var(--selection-foreground);\n}",
    ].join("\n\n"),
  ],
  [
    "tailwind.css",
    [
      "/* gg-theme — Tailwind v4 entry. Generated from theme/palette.ts. Do not edit. */",
      '@import "./index.css";',
      [
        "@theme inline {",
        ...slotNames
          .filter((name) => !name.startsWith("selection"))
          .map((name) => `  --color-${name}: var(--${name});`),
        "",
        "  --radius-sm: calc(var(--radius) - 4px);",
        "  --radius-md: calc(var(--radius) - 2px);",
        "  --radius-lg: var(--radius);",
        "  --radius-xl: calc(var(--radius) + 4px);",
        "}",
      ].join("\n"),
      "@custom-variant dark (&:where(.dark, .dark *));",
    ].join("\n\n"),
  ],
  [
    "primitives.css",
    [
      "/* gg-theme primitives — generated from theme/palette.ts. Do not edit.\n" +
        "   The un-roled palette, for layers that map it to their own vocabulary\n" +
        "   instead of consuming the shadcn slots in index.css. After the palette\n" +
        "   come the tiers derived from it: soft (text), quiet (receding), wash and\n" +
        "   tint (backgrounds). */",
      ...webModes.map((mode) =>
        cssBlock(webSelectors[mode], mode, [
          ...Object.entries(palettes[mode]).map(
            ([name, color]) => [`gg-${kebab(name)}`, oklchCss(color)] as [string, string],
          ),
          ...Object.entries(tiersByMode[mode]).map(
            ([name, color]) => [`gg-${kebab(name)}`, oklchCss(color)] as [string, string],
          ),
          ["gg-link", oklchCss(slotsByMode[mode].link)],
          ["gg-link-visited", oklchCss(slotsByMode[mode]["link-visited"])],
          ...Object.entries(deprecatedPre020Aliases).map(([name, source]) => [name, `var(--gg-${source})`] as [string, string]),
        ]),
      ),
    ].join("\n\n"),
  ],
  [
    "tokens.json",
    JSON.stringify(
      {
        name: "gg-theme",
        version: webPackage.version,
        modes: Object.fromEntries(
          webModes.map((mode) => [
            mode,
            Object.fromEntries(Object.entries(slotsByMode[mode]).filter(([, value]) => value.startsWith("#"))),
          ]),
        ),
        palette: Object.fromEntries(
          webModes.map((mode) => [
            mode,
            Object.fromEntries(Object.entries(palettes[mode]).map(([name, color]) => [kebab(name), color])),
          ]),
        ),
        tiers: Object.fromEntries(
          webModes.map((mode) => [
            mode,
            Object.fromEntries(Object.entries(tiersByMode[mode]).map(([name, color]) => [kebab(name), color])),
          ]),
        ),
        radius: webRadius,
      },
      null,
      2,
    ),
  ],
];

const deriveSource = await readFile(new URL("./derive.ts", import.meta.url), "utf8");
webOutputs.push([
  "derive.js",
  `// gg-theme derive — generated from theme/derive.ts. Do not edit.\n${stripTypeScriptTypes(deriveSource).replace(/[ \t]+$/gm, "").trimEnd()}`,
]);

for (const [file, output] of webOutputs) {
  await writeAtomic(join(webRoot, file), `${output}\n`);
  console.log(`generated theme/web/${file}`);
}
