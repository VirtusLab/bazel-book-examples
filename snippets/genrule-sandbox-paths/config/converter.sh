#!/usr/bin/env bash
set -euo pipefail

input="$1"
tr '[:lower:]' '[:upper:]' < "$input"
