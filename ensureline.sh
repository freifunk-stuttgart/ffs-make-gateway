ensureline() {
  LINE="$1"
  FILE="$2"
  if [ ! -e "$FILE" ]; then
    touch "$FILE" || return 1
  fi
  egrep -q '^'"$LINE"'$' "$FILE" || echo "$LINE" | tr -d '\\' >> "$FILE" || return 1
}


ensureline_insert() {
  LINE="$1"
  FILE="$2"
  if [ ! -e "$FILE" ]; then
    touch "$FILE" || return 1
  fi
  egrep -q '^'"$LINE"'$' "$FILE" || sed -i "/^exit 0/i$LINE" "$FILE" || return 1
}

