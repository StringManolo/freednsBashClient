#!/usr/bin/env bash

# Download the webpage https://freedns.afraid.org/domain/registry/ to get domains

updateSubdomainList() {
  local CONFIG_FILE="subdomainList.config"
  local html_file="$1"

  if [[ ! -f "$html_file" ]]; then
    echo "Error: HTML file '$html_file' not found" >&2
    return 1
  fi

  echo "Generating ..." >&2

  grep -o 'edit_domain_id=[0-9]*"[^>]*>[^<]*' "$html_file" | \
  sed 's/edit_domain_id=\([0-9]*\)"[^>]*>\(.*\)/\2 \1/' > "$CONFIG_FILE"

  local count=$(wc -l < "$CONFIG_FILE")
}

updateSubdomainList domainsList.html && echo "subdomainList.config file generated"

