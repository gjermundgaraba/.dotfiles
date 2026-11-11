// Types for derive.js. Hand-written: keep in step with theme/derive.ts's exports.

export type Mode = "dark" | "light";

export declare const hueNames: readonly ["accent", "red", "green", "yellow", "blue", "magenta", "cyan", "orange"];

export type HueName = (typeof hueNames)[number];

/** The palette colours the tiers are derived from, as #rrggbb under tokens.json's keys. */
export type TierInputs = Readonly<Record<"bg" | "surface" | "fg" | "fg-dim" | HueName, string>>;

/** The tiers' names: wash, and per hue wash-*, tint-*, soft-* and quiet-*. */
export type TierName = "wash" | `${"wash" | "tint" | "soft" | "quiet"}-${HueName}`;

/** Derived tiers as #rrggbb strings. */
export type Tiers = Readonly<Record<TierName, string>>;

/** A #rrggbb colour's red, green and blue bytes. */
export declare function channels(hex: string): number[];

/** OKLCH lightness, chroma and hue (radians). */
export declare function toOklch(hex: string): [lightness: number, chroma: number, hue: number];

export declare function fromOklch(oklch: [lightness: number, chroma: number, hue: number]): string;

/** Mixes two #rrggbb colours in sRGB; `amount` 0 gives `color`, 1 gives `other`. */
export declare function mix(color: string, other: string, amount: number): string;

/** WCAG 2 contrast ratio of two #rrggbb colours. */
export declare function contrast(a: string, b: string): number;

/**
 * Steps `source`'s OKLCH lightness away from the backgrounds (lighter in dark
 * mode) until it reaches `minimum` contrast on all of them; throws if none does.
 */
export declare function readable(mode: Mode, label: string, source: string, backgrounds: string[], minimum: number): string;

/**
 * The tiers tokens.json publishes, in its order: wash, then per hue wash-*,
 * tint-*, soft-* and quiet-*. Throws when a soft or quiet tier cannot be made
 * readable. Use checkPalette for the remaining contrast rules.
 */
export declare function deriveTiers(mode: Mode, palette: TierInputs): Tiers;

/**
 * Every contrast rule the palette breaks, as messages without the mode; empty
 * when it passes.
 * Checks each rule whose colours are present; with all of TierInputs present
 * it also checks FG and the syntax colours on the derived washes and tints.
 */
export declare function checkPalette(mode: Mode, palette: Readonly<Record<string, string>>): string[];
