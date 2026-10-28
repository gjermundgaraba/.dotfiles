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
  IFS= read -r used_tokens
} < <(jq -r '
  .workspace.current_dir // .cwd // "",
  .model.display_name // "",
  (.context_window.remaining_percentage // ""),
  (.effort.level // ""),
  (.output_style.name // ""),
  (.rate_limits.five_hour.used_percentage // ""),
  (.rate_limits.seven_day.used_percentage // ""),
  (.context_window.total_input_tokens // "")
' <<<"$input")

# Claude Code doesn't expose its auto-compact window here, so read the user
# setting (an integer token count). Unset keeps the model-window percentage.
compact_window=$(jq -r '.autoCompactWindow | numbers' "$HOME/.claude/settings.json" 2>/dev/null)

if [ -n "$compact_window" ] && [ "$compact_window" -gt 0 ] && [ -n "$remaining" ] && [ -n "$used_tokens" ]; then
  remaining=$(( 100 - used_tokens * 100 / compact_window ))
  [ "$remaining" -lt 0 ] && remaining=0
fi

reset=$'\033[0m'
dim=$'\033[2m'
curly_ul=$'\033[4:3m'

sep="${dim} ‧ ${reset}"

short_cwd=${cwd/#$HOME/\~}

short_model_name() {
  local name=${1% \(*\)}
  printf '%s%s' "$(printf '%s' "${name:0:1}" | tr '[:upper:]' '[:lower:]')" "${name:1}"
}

model=$(short_model_name "$model_raw")

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

low_context_pct=25
mega_rounding_floor=999950

if [ -n "$remaining" ]; then
  rem_int=$(printf "%.0f" "$remaining")
  if [ "$rem_int" -le "$low_context_pct" ] 2>/dev/null; then
    ctx_val="${curly_ul}${rem_int}%${reset} left"
  else
    ctx_val="${rem_int}% left"
  fi
  if [ -n "$used_tokens" ]; then
    used_fmt=$(awk -v n="$used_tokens" -v mega_floor="$mega_rounding_floor" 'BEGIN{
      if (n >= mega_floor) { s = sprintf("%.1f", n/1000000); u = "M" }
      else if (n >= 1000) { s = sprintf("%.1f", n/1000); u = "k" }
      else { s = n; u = "" }
      sub(/\.0$/, "", s); print s u
    }')
    ctx_val="${used_fmt}, ${ctx_val}"
  fi
  segments+=("${dim}ctx ${reset}${ctx_val}")
fi

if [ -n "$effort" ]; then
  segments+=("${dim}⚡ ${reset}${effort}")
elif [ -n "$output_style" ] && [ "$output_style" != "default" ]; then
  segments+=("${dim}⚡ ${reset}${output_style}")
fi

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
