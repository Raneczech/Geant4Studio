#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

export GEANT4_DIR="${GEANT4_DIR:-$HOME/geant4/install}"
source "$GEANT4_DIR/bin/geant4.sh"

cmake -S . -B build \
    -DGeant4_DIR="$GEANT4_DIR/lib/cmake/Geant4"

cmake --build build -j"$(nproc)"
