#!/usr/bin/env bash
export LC_ALL=C

input=$(cat)

{
  IFS= read -r cwd
  IFS= read -r model_raw
  IFS= read -r remaining
  IFS= read -r effort
  IFS= read -r output_style
  IFS= read -r five_pct
  IFS= read -r week_pct
} < <(jq -r '
  .workspace.current_dir // .cwd // "",
  .model.display_name // "",
  (.context_window.remaining_percentage // ""),
  (.effort.level // ""),
  (.output_style.name // ""),
  (.rate_limits.five_hour.used_percentage // ""),
  (.rate_limits.seven_day.used_percentage // "")
' <<<"$input")

# ANSI helpers — no colors, weight/style only
reset=$'\033[0m'
dim=$'\033[2m'
curly_ul=$'\033[4:3m'        # curly underline for low-context warning

# Separator: hyphenation point (U+2027) surrounded by single spaces, dimmed
sep="${dim} ‧ ${reset}"

short_cwd=${cwd/#$HOME/\~}

# Strip "(1M context)" or similar parenthetical suffix, then lowercase its first letter
# e.g. "Opus 4.7 (1M context)" -> "opus 4.7"
model=${model_raw% \(*\)}
model="$(printf '%s' "${model:0:1}" | tr '[:upper:]' '[:lower:]')${model:1}"

segments=()

if [ -n "$short_cwd" ]; then
  segments+=("$short_cwd")
fi

branch=$(GIT_OPTIONAL_LOCKS=0 git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null)
if [ -n "$branch" ]; then
  segments+=("$branch")
fi

if [ -n "$model" ]; then
  segments+=("${dim}󰭆 ${reset}${model}")
fi

# Context remaining — phrased as "left" so the number is unambiguous at a glance,
# curly underline as a low-context warning once less than 25% remains
if [ -n "$remaining" ]; then
  rem_int=$(printf "%.0f" "$remaining")
  if [ "$rem_int" -le 25 ] 2>/dev/null; then
    ctx_val="${curly_ul}${rem_int}%${reset} left"
  else
    ctx_val="${rem_int}% left"
  fi
  segments+=("${dim}ctx ${reset}${ctx_val}")
fi

if [ -n "$effort" ]; then
  segments+=("${dim}⚡ ${reset}${effort}")
elif [ -n "$output_style" ] && [ "$output_style" != "default" ]; then
  segments+=("${dim}⚡ ${reset}${output_style}")
fi

# Rate limits — labeled "sess"/"week" (rather than "5h"/"7d") and spelled out as
# "used" so the numbers read as plan-usage, not context or time remaining
if [ -n "$five_pct" ] || [ -n "$week_pct" ]; then
  rate_seg=""
  if [ -n "$five_pct" ]; then
    five_int=$(printf "%.0f" "$five_pct")
    rate_seg="${dim}sess used ${reset}${five_int}%"
  fi
  if [ -n "$week_pct" ]; then
    week_int=$(printf "%.0f" "$week_pct")
    [ -n "$rate_seg" ] && rate_seg+=" "
    rate_seg+="${dim}week used ${reset}${week_int}%"
  fi
  segments+=("$rate_seg")
fi

out=""
for seg in "${segments[@]}"; do
  if [ -z "$out" ]; then
    out="$seg"
  else
    out="${out}${sep}${seg}"
  fi
done

printf "%s" "$out"
