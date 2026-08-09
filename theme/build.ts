import { mkdir, readFile, rename, writeFile } from "node:fs/promises";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { palettes } from "./palette.ts";

const root = fileURLToPath(new URL("../", import.meta.url));
const neovimTemplate = await readFile(new URL("./templates/neovim.lua", import.meta.url), "utf8");
const ghosttyTemplate = await readFile(new URL("./templates/ghostty", import.meta.url), "utf8");
const fishTemplate = await readFile(new URL("./templates/fish.theme", import.meta.url), "utf8");
const modes = ["dark", "light"] as const;
const expectedKeys = Object.keys(palettes.dark).sort().join(",");

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
    ["FG", "BG", 4.5],
    ["Overlay", "BG", 3],
    ["FG", "Overlay", 3],
    ["FGDim", "BG", 3],
    ["FGDim", "Surface", 3],
    ["SelectionFG", "SelectionBG", 4.5],
  ];
  for (const color of ["Red", "Green", "Yellow", "Blue", "Magenta", "Cyan", "Orange"]) {
    pairs.push([color, "BG", 4.5]);
  }
  for (const [foreground, background, minimum] of pairs) {
    const ratio = contrast(palette[foreground], palette[background]);
    if (ratio < minimum) {
      throw new Error(`${mode}.${foreground}/${background} contrast is ${ratio.toFixed(2)}; need ${minimum}`);
    }
  }
}

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
  validate(mode, palette);
  const values = {
    ...palette,
    Name: `gg-${mode}`,
    Background: mode,
    AnsiBlack: mode === "dark" ? palette.BG : palette.FGDim,
    AnsiWhite: mode === "dark" ? palette.FG : palette.Overlay,
    BrightBlack: palette.Overlay,
    BrightWhite: mode === "dark" ? palette.FG : palette.Surface,
  };
  const fishValues = Object.fromEntries(
    Object.entries(values).map(([name, value]) => [name, value.replace(/^#/, "")]),
  );
  const outputs = [
    [join(root, "home", ".config", "nvim", "colors", `gg-${mode}.lua`), render(neovimTemplate, values)],
    [join(root, "home", ".config", "ghostty", "themes", `gg-${mode}`), render(ghosttyTemplate, values)],
    [join(root, "home", ".config", "fish", "themes", `gg-${mode}.theme`), render(fishTemplate, fishValues)],
  ];

  for (const [destination, output] of outputs) {
    await writeAtomic(destination, output);
    console.log(`generated ${destination.slice(root.length)}`);
  }
}
