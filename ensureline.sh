ensureline() {
  LINE="$1"
  FILE="$2"
  if [ ! -e "$FILE" ]; then
    touch "$FILE" || return 1
  fi
  egrep -q '^'"$LINE"'$' "$FILE" || echo "$LINE" >> "$FILE" || return 1
}

ensureline_exp() {
  LINE="$1"
  FILE="$2"
  if [ ! -e "$FILE" ]; then
    touch "$FILE" || return 1
  fi
  fgrep -q "$LINE" "$FILE" || echo "$LINE" >> "$FILE" || return 1
}

ensureline_tr() {
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


replaceline() {
  LINE="$1"
  LINE2="$2"
  FILE="$3"
  if [ ! -e "$FILE" ]; then
    return 1
  fi
  sed -i "s/^$LINE/$LINE2/" "$FILE" || return 1
}

