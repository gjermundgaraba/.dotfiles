import { mkdir, readFile, rename, writeFile } from "node:fs/promises";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
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

type Oklch = [lightness: number, chroma: number, hue: number];

function toOklch(hex: string): Oklch {
  const [r, g, b] = [1, 3, 5]
    .map((offset) => parseInt(hex.slice(offset, offset + 2), 16) / 255)
    .map((value) => (value <= 0.04045 ? value / 12.92 : ((value + 0.055) / 1.055) ** 2.4));
  const l = Math.cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b);
  const m = Math.cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b);
  const s = Math.cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b);
  const a = 1.9779984951 * l - 2.428592205 * m + 0.4505937099 * s;
  const bb = 0.0259040371 * l + 0.7827717662 * m - 0.808675766 * s;
  return [0.2104542553 * l + 0.793617785 * m - 0.0040720468 * s, Math.hypot(a, bb), Math.atan2(bb, a)];
}

function fromOklch([lightness, chroma, hue]: Oklch): string {
  const a = chroma * Math.cos(hue);
  const b = chroma * Math.sin(hue);
  const l = (lightness + 0.3963377774 * a + 0.2158037573 * b) ** 3;
  const m = (lightness - 0.1055613458 * a - 0.0638541728 * b) ** 3;
  const s = (lightness - 0.0894841775 * a - 1.291485548 * b) ** 3;
  const channels = [
    4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
    -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
    -0.0041960863 * l - 0.7034186147 * m + 1.707614701 * s,
  ].map((value) => {
    const encoded = value <= 0.0031308 ? value * 12.92 : 1.055 * value ** (1 / 2.4) - 0.055;
    return Math.round(Math.min(1, Math.max(0, encoded)) * 255).toString(16).padStart(2, "0");
  });
  return `#${channels.join("")}`;
}

function mix(color: string, other: string, amount: number): string {
  const channels = [1, 3, 5].map((offset) =>
    Math.round(
      parseInt(color.slice(offset, offset + 2), 16) * (1 - amount) +
      parseInt(other.slice(offset, offset + 2), 16) * amount,
    ).toString(16).padStart(2, "0"),
  );
  return `#${channels.join("")}`;
}

function tint(surface: string, hueSource: string, chroma: number): string {
  return fromOklch([toOklch(surface)[0], chroma, toOklch(hueSource)[2]]);
}

function readable(
  mode: (typeof modes)[number],
  label: string,
  source: string,
  backgrounds: string[],
  minimum: number,
): string {
  const step = mode === "dark" ? 0.005 : -0.005;
  let [lightness, chroma, hue] = toOklch(source);
  let color = fromOklch([lightness, chroma, hue]);
  while (backgrounds.some((background) => contrast(color, background) < minimum)) {
    lightness += step;
    if (lightness <= 0 || lightness >= 1) throw new Error(`${mode}.${label} cannot reach ${minimum} contrast`);
    color = fromOklch([lightness, chroma, hue]);
  }
  return color;
}

const hues = ["Accent", "Red", "Green", "Yellow", "Blue", "Magenta", "Cyan", "Orange"] as const;
const softChromaScale = { dark: 0.6, light: 1 } as const;
const softMaxLightness = { dark: 0.8, light: 1 } as const;
const quietLightnessStep = -0.08;
const quietChromaScale = 0.6;
const washChroma = 0.03;
const tintChroma = { dark: 0.065, light: 0.04 } as const;

function tiers(mode: (typeof modes)[number], palette: Record<string, string>): Record<string, string> {
  const colors: Record<string, string> = { Wash: mix(palette.BG, palette.Surface, 0.5) };
  for (const hue of hues) {
    colors[`Wash${hue}`] = tint(colors.Wash, palette[hue], washChroma);
    colors[`Tint${hue}`] = tint(colors.Wash, palette[hue], tintChroma[mode]);
  }
  for (const [name, background] of Object.entries(colors)) {
    const ratio = contrast(palette.FG, background);
    if (ratio < 7) throw new Error(`${mode}.FG/${name} contrast is ${ratio.toFixed(2)}; need 7`);
  }

  const washes = Object.keys(colors).filter((name) => name.startsWith("Wash"));
  const textBackgrounds = [palette.BG, palette.Surface, ...washes.map((name) => colors[name])];
  for (const hue of hues) {
    const [lightness, chroma, angle] = toOklch(palette[hue]);
    const soft = readable(
      mode,
      `Soft${hue}`,
      fromOklch([Math.min(lightness, softMaxLightness[mode]), chroma * softChromaScale[mode], angle]),
      textBackgrounds,
      textContrast,
    );
    const [softLightness, softChroma] = toOklch(soft);
    colors[`Soft${hue}`] = soft;
    colors[`Quiet${hue}`] = readable(
      mode,
      `Quiet${hue}`,
      fromOklch([softLightness + quietLightnessStep, softChroma * quietChromaScale, angle]),
      [palette.BG],
      nonTextContrast,
    );
  }
  return colors;
}

function luminance(hex: string): number {
  const channels = hex.match(/[0-9a-f]{2}/gi)!.map((value) => parseInt(value, 16) / 255);
  const [red, green, blue] = channels.map((value) =>
    value <= 0.04045 ? value / 12.92 : ((value + 0.055) / 1.055) ** 2.4,
  );
  return 0.2126 * red + 0.7152 * green + 0.0722 * blue;
}

function contrast(a: string, b: string): number {
  const [lighter, darker] = [luminance(a), luminance(b)].sort((x, y) => y - x);
  return (lighter + 0.05) / (darker + 0.05);
}

function validate(mode: (typeof modes)[number], palette: Record<string, string>): void {
  if (Object.keys(palette).sort().join(",") !== expectedKeys) {
    throw new Error(`${mode} palette does not have the same tokens as dark`);
  }

  for (const [name, color] of Object.entries(palette)) {
    if (!/^#[0-9a-f]{6}$/i.test(color)) throw new Error(`${mode}.${name} is not a hex color`);
  }

  const pairs: [string, string, number][] = [
    ["Accent", "BG", nonTextContrast],
    ["FG", "BG", textContrast],
    ["TerminalFG", "BG", textContrast],
    ["AnsiWhite", "BG", nonTextContrast],
    ["Overlay", "BG", nonTextContrast],
    ["FG", "Overlay", nonTextContrast],
    ["FGDim", "BG", textContrast],
    ["FGDim", "Surface", textContrast],
    ["SelectionFG", "SelectionBG", textContrast],
  ];
  for (const color of ["Red", "Green", "Yellow", "Blue", "Magenta", "Cyan", "Orange"]) {
    pairs.push([color, "BG", textContrast]);
  }
  for (const [foreground, background, minimum] of pairs) {
    const ratio = contrast(palette[foreground], palette[background]);
    if (ratio < minimum) {
      throw new Error(`${mode}.${foreground}/${background} contrast is ${ratio.toFixed(2)}; need ${minimum}`);
    }
  }
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
  const outputs = [
    [join(root, "home", ".pi", "agent", "themes", `gg-${mode}.json`), render(piTemplate, values)],
    [join(root, "home", ".config", "nvim", "colors", `gg-${mode}.lua`), render(neovimTemplate, values)],
    [join(root, "home", ".config", "ghostty", "themes", `gg-${mode}`), render(ghosttyTemplate, values)],
    [join(root, "home", ".config", "fish", "themes", `gg-${mode}.theme`), render(fishTemplate, fishValues)],
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
  slots.link = readable(mode, "link", palette.Accent, [palette.BG, palette.Surface], textContrast);
  slots["link-visited"] = readable(mode, "link-visited", tier.QuietAccent, [palette.BG, palette.Surface], textContrast);
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

for (const [file, output] of webOutputs) {
  await writeAtomic(join(webRoot, file), `${output}\n`);
  console.log(`generated theme/web/${file}`);
}
