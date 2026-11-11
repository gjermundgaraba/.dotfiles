// gg-theme derive — generated from theme/derive.ts. Do not edit.
// Derives a palette's tiers and checks its contrast. Self-contained, with no
// imports: build.ts uses it, and the build strips its types into
// theme/web/derive.js, which the web package exports as
// @gjermundgaraba/gg-theme/derive. Colours and names use tokens.json's shape:
// #rrggbb strings under kebab-case keys.



export const hueNames = ["accent", "red", "green", "yellow", "blue", "magenta", "cyan", "orange"]         ;



/** The palette colours the tiers are derived from. */




const textContrast = 4.5;
const nonTextContrast = 3;
const syntaxColors = ["red", "green", "yellow", "blue", "magenta", "cyan", "orange", "fg-dim"]         ;
const softChromaScale = { dark: 0.6, light: 1 }         ;
const softMaxLightness = { dark: 0.8, light: 1 }         ;
const quietLightnessStep = { dark: -0.08, light: 0.08 }         ;
const quietChromaScale = 0.6;
const washChroma = 0.03;
const tintChroma = { dark: 0.065, light: 0.04 }         ;

const contrastPairs                                                              = [
  ["accent", "bg", nonTextContrast],
  ["fg", "bg", textContrast],
  ["terminal-fg", "bg", textContrast],
  ["ansi-white", "bg", nonTextContrast],
  ["overlay", "bg", nonTextContrast],
  ["fg", "overlay", nonTextContrast],
  ["fg-dim", "bg", textContrast],
  ["fg-dim", "surface", textContrast],
  ["selection-fg", "selection-bg", textContrast],
  ...syntaxColors.flatMap((color) =>
    ["bg", "surface", "selection-bg"].map((background)                           => [color, background, textContrast]),
  ),
];

/** A #rrggbb colour's red, green and blue bytes. */
export function channels(hex        )           {
  return [1, 3, 5].map((offset) => parseInt(hex.slice(offset, offset + 2), 16));
}

function linear(byte        )         {
  const value = byte / 255;
  return value <= 0.04045 ? value / 12.92 : ((value + 0.055) / 1.055) ** 2.4;
}

export function toOklch(hex        )        {
  const [r, g, b] = channels(hex).map(linear);
  const l = Math.cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b);
  const m = Math.cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b);
  const s = Math.cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b);
  const a = 1.9779984951 * l - 2.428592205 * m + 0.4505937099 * s;
  const bb = 0.0259040371 * l + 0.7827717662 * m - 0.808675766 * s;
  return [0.2104542553 * l + 0.793617785 * m - 0.0040720468 * s, Math.hypot(a, bb), Math.atan2(bb, a)];
}

export function fromOklch([lightness, chroma, hue]       )         {
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

export function mix(color        , other        , amount        )         {
  const [from, to] = [channels(color), channels(other)];
  const mixed = from.map((value, index) =>
    Math.round(value * (1 - amount) + to[index] * amount).toString(16).padStart(2, "0"),
  );
  return `#${mixed.join("")}`;
}

function tint(surface        , hueSource        , chroma        )         {
  return fromOklch([toOklch(surface)[0], chroma, toOklch(hueSource)[2]]);
}

function luminance(hex        )         {
  const [red, green, blue] = channels(hex).map(linear);
  return 0.2126 * red + 0.7152 * green + 0.0722 * blue;
}

/** WCAG 2 contrast ratio of two #rrggbb colours. */
export function contrast(a        , b        )         {
  const [lighter, darker] = [luminance(a), luminance(b)].sort((x, y) => y - x);
  return (lighter + 0.05) / (darker + 0.05);
}

/**
 * Steps `source`'s OKLCH lightness away from the backgrounds (lighter in dark
 * mode) until it reaches `minimum` contrast on all of them; throws if none does.
 */
export function readable(mode      , label        , source        , backgrounds          , minimum        )         {
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

/**
 * The tiers tokens.json publishes, in its order: wash (between BG and Surface),
 * and per hue wash-*, tint-* (backgrounds), soft-* (text) and quiet-*
 * (receding). Soft and quiet step their lightness until readable; throws when
 * one cannot be. Use checkPalette for the remaining contrast rules.
 */
export function deriveTiers(mode      , palette            )                         {
  const colors                         = { wash: mix(palette.bg, palette.surface, 0.5) };
  for (const hue of hueNames) {
    colors[`wash-${hue}`] = tint(colors.wash, palette[hue], washChroma);
    colors[`tint-${hue}`] = tint(colors.wash, palette[hue], tintChroma[mode]);
  }

  const washes = Object.keys(colors).filter((name) => name.startsWith("wash"));
  const textBackgrounds = [palette.bg, palette.surface, ...washes.map((name) => colors[name])];
  for (const hue of hueNames) {
    const [lightness, chroma, angle] = toOklch(palette[hue]);
    const soft = readable(
      mode,
      `soft-${hue}`,
      fromOklch([Math.min(lightness, softMaxLightness[mode]), chroma * softChromaScale[mode], angle]),
      textBackgrounds,
      textContrast,
    );
    const [softLightness, softChroma] = toOklch(soft);
    colors[`soft-${hue}`] = soft;
    colors[`quiet-${hue}`] = readable(
      mode,
      `quiet-${hue}`,
      fromOklch([softLightness + quietLightnessStep[mode], softChroma * quietChromaScale, angle]),
      [palette.bg],
      nonTextContrast,
    );
  }
  return colors;
}

const tierInputNames = ["bg", "surface", "fg", "fg-dim", ...hueNames]         ;

function hasTierInputs(palette                                  )                        {
  return tierInputNames.every((name) => name in palette);
}

/**
 * Every contrast rule the palette breaks, as messages; empty when it passes.
 * Checks each rule whose colours are present, so a palette without the
 * terminal colours is checked on the rest. With all of TierInputs present it
 * also derives the tiers and checks FG (7:1) and the syntax colours (4.5:1) on
 * each wash and tint.
 */
export function checkPalette(mode      , palette                                  )           {
  const problems = Object.entries(palette)
    .filter(([, color]) => !/^#[0-9a-f]{6}$/i.test(color))
    .map(([name]) => `${mode}.${name} is not a hex color`);
  if (problems.length > 0) return problems;

  for (const [foreground, background, minimum] of contrastPairs) {
    if (!(foreground in palette) || !(background in palette)) continue;
    const ratio = contrast(palette[foreground], palette[background]);
    if (ratio < minimum) {
      problems.push(`${mode}.${foreground}/${background} contrast is ${ratio.toFixed(2)}; need ${minimum}`);
    }
  }
  if (!hasTierInputs(palette)) return problems;

  let tiers                        ;
  try {
    tiers = deriveTiers(mode, palette);
  } catch (error) {
    return [...problems, error instanceof Error ? error.message : String(error)];
  }
  for (const [name, background] of Object.entries(tiers)) {
    if (!name.startsWith("wash") && !name.startsWith("tint")) continue;
    const ratio = contrast(palette.fg, background);
    if (ratio < 7) problems.push(`${mode}.fg/${name} contrast is ${ratio.toFixed(2)}; need 7`);
    if (!name.startsWith("tint")) continue;
    for (const color of syntaxColors) {
      const syntaxRatio = contrast(palette[color], background);
      if (syntaxRatio < textContrast) {
        problems.push(`${mode}.${color}/${name} contrast is ${syntaxRatio.toFixed(2)}; need ${textContrast}`);
      }
    }
  }
  return problems;
}
