#!/bin/bash
# Renames burrito_out/ binaries to include the app version from mix.exs

set -e

VERSION=$(grep 'version:' mix.exs | head -1 | sed 's/.*"\(.*\)".*/\1/')

if [ -z "$VERSION" ]; then
  echo "Error: could not extract version from mix.exs"
  exit 1
fi

if [ ! -d "burrito_out" ]; then
  echo "Error: burrito_out/ directory not found"
  exit 1
fi

for f in burrito_out/boxwallet_*; do
  newname=$(echo "$f" | sed "s/boxwallet_/boxwallet_${VERSION}_/")
  mv "$f" "$newname"
  echo "Renamed: $(basename "$f") -> $(basename "$newname")"
done
