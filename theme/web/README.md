# gg-theme

Coordinated light and dark CSS variables for web apps. Generated from the same palette as my terminal, Neovim, and agent themes, so everything matches. Compatible with Tailwind CSS v4, shadcn/ui, and any tool that reads CSS custom properties.

## Install

```bash
npm install @gjermundgaraba/gg-theme
```

## Use

### Plain CSS

```css
@import "@gjermundgaraba/gg-theme";
```

Then toggle modes by adding `class="dark"` to `<html>` (manually, with `next-themes`, or any other theme manager). The base `:root` block is light; `.dark` overrides every token.

### Tailwind CSS v4

```css
@import "tailwindcss";
@import "@gjermundgaraba/gg-theme/tailwind";
```

`@gjermundgaraba/gg-theme/tailwind` re-exports all tokens through `@theme inline`, so utilities like `bg-background`, `text-foreground`, `bg-primary`, `border-border`, `bg-chart-1` work out of the box. The bundled `@custom-variant dark` matches the `.dark` class.

### shadcn/ui

shadcn components reference tokens by their bare names (`--background`, `--primary`, …) which is exactly the contract this package emits. Drop the import in `globals.css` and remove shadcn's default block.

## Tokens

| Surface | Foreground | Used for |
| --- | --- | --- |
| `background` | `foreground` | Page chrome and body text. |
| `card` | `card-foreground` | Elevated panels, sheets, dialogs. |
| `popover` | `popover-foreground` | Floating menus, tooltips, popovers. |
| `primary` | `primary-foreground` | Brand action: primary buttons, active links. |
| `secondary` | `secondary-foreground` | Quiet alternative action. |
| `muted` | `muted-foreground` | Subdued surfaces and metadata text. |
| `accent` | `accent-foreground` | Hover and highlight surfaces. |
| `destructive` | `destructive-foreground` | Delete, irreversible actions, errors. |
| `success` | `success-foreground` | Confirmations, completed state. |
| `warning` | `warning-foreground` | Attention, recoverable issues. |
| `info` | `info-foreground` | Neutral informational state. |

| Token | Used for |
| --- | --- |
| `border` | Default 1px borders. |
| `input` | Form-control borders, slightly stronger than `border`. |
| `ring` | Focus ring. |
| `link` / `link-visited` | The accent as link text, stepped only as far as reading contrast demands; visited is the quiet tier. Both pass 4.5:1 on `background` and `card`. |
| `selection` / `selection-foreground` | Text selection. |
| `chart-1` … `chart-5` | Qualitative data viz palette. |
| `radius` | Base corner radius (Tailwind derives `radius-sm/md/lg/xl`). |

## Files

| Export | Path |
| --- | --- |
| `@gjermundgaraba/gg-theme` | `index.css`, base CSS variables (`:root` + `.dark`). |
| `@gjermundgaraba/gg-theme/tailwind` | `tailwind.css`, Tailwind v4 `@theme inline` mapping. |
| `@gjermundgaraba/gg-theme/primitives` | `primitives.css`, the un-roled palette as `--gg-*` OKLCH custom properties for downstream layers, followed by the tiers derived from each hue: `--gg-soft-*` (text), `--gg-quiet-*` (borders, receding text), `--gg-wash-*` (row backgrounds) and `--gg-tint-*` (highlight backgrounds), plus `--gg-link` and `--gg-link-visited`. |
| `@gjermundgaraba/gg-theme/tokens` | `tokens.json`, slot and palette values as hex for tooling and JS. |
| `@gjermundgaraba/gg-theme/derive` | `derive.js` (with `derive.d.ts`), the code that derives the tiers from a palette and checks its contrast, for tools that let people bring their own palette. |

## Deriving tiers from your own palette

`deriveTiers(mode, palette)` takes a palette in `tokens.json`'s shape (`bg`, `surface`, `fg`, `fg-dim` and the hues `accent`, `red`, `green`, `yellow`, `blue`, `magenta`, `cyan`, `orange`, as `#rrggbb`) and returns its tiers exactly as `tokens.json` lists them. It throws only when a soft or quiet tier cannot be made readable. `checkPalette(mode, palette)` returns every contrast rule the palette breaks, checking the rules whose colours are present.

```js
import { checkPalette, deriveTiers } from "@gjermundgaraba/gg-theme/derive";
import tokens from "@gjermundgaraba/gg-theme/tokens" with { type: "json" };

deriveTiers("dark", tokens.palette.dark); // deep-equals tokens.tiers.dark
checkPalette("dark", { ...tokens.palette.dark, bg: "#ffffff" }); // ["dark.accent/bg contrast is 2.70; need 3", …]
```

## Notes

Every foreground is pre-paired with its surface and checked at build time: text pairs meet WCAG AA (4.5:1), and the focus ring clears 3:1 on both `background` and `card`. Status fills keep the palette's lightness and hue at reduced chroma, so large fills do not glare. Borders use `color-mix` against `--foreground`, so they self-tune in both modes.

## Development

The CSS, JSON and `derive.js` files are generated; `derive.d.ts` is written by hand and must match `theme/derive.ts`'s exports. Edit `theme/palette.ts` in the [source repository](https://github.com/gjermundgaraba/.dotfiles), run `node theme/build.ts`, bump `version` here, and push to `main`. CI publishes any version that is not yet on npm.
