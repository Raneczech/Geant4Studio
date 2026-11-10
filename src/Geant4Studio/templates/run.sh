#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

export GEANT4_DIR="${GEANT4_DIR:-$HOME/geant4/install}"
source "$GEANT4_DIR/bin/geant4.sh"

export PYTHIA8DATA="$HOME/geant4/pythia8318/share/Pythia8/xmldoc"

exec "./build/PROJECT_NAME" "$@"
