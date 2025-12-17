#!/bin/bash

# Stop the script if any command fails
set -e

# --- CONFIGURATION ---
APP_NAME="boxwallet" # Replace with your app name from mix.exs
VERSION="0.0.5"   # You could also extract this dynamically from mix.exs

echo "🚀 Starting build for $APP_NAME v$VERSION..."

# 1. Set the environment to Production
export MIX_ENV=prod

# 2. Get Production Dependencies
echo "📦 Fetching dependencies..."
mix deps.get --only prod

# 3. Compile the application
echo "🔨 Compiling..."
mix compile

# 4. Build Assets (Uncomment if using Phoenix/Tailwind/Esbuild)
echo "🎨 Building assets..."
mix assets.deploy

# 5. Generate the Release
echo "💿 Generating Release..."
# Overwrite existing releases to ensure a fresh build
mix release --overwrite

# 6. Compress the Release
echo "📦 Compressing..."
RELEASE_DIR="_build/prod/rel/$APP_NAME"
OUTPUT_FILE="$APP_NAME-$VERSION-linux-x64.tar.gz"

# We change directory to the release folder so the zip file
# doesn't contain the long path "_build/prod/rel/..."
# It will just contain the folder "my_app"
tar -czf "$OUTPUT_FILE" -C "_build/prod/rel" "$APP_NAME"

echo "✅ Done! Your file is ready at:"
echo "$PWD/$OUTPUT_FILE"
