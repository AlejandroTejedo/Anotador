#!/bin/sh
# Vuelca en Localizable.xcstrings los textos nuevos del código.
# Xcode lo hace solo al compilar desde el IDE; desde la terminal hay que pedirlo.
set -eu
cd "$(dirname "$0")/.."
DERIVED="${DERIVED_DATA:-build/DerivedData}"

xcodebuild build -scheme Anotador -destination 'platform=macOS' -derivedDataPath "$DERIVED" -quiet

set --
for file in "$DERIVED"/Build/Intermediates.noindex/Anotador.build/Debug/Anotador.build/Objects-normal/*/*.stringsdata; do
    set -- "$@" --stringsdata "$file"
done
xcrun xcstringstool sync Anotador/Localizable.xcstrings "$@"
echo "Catálogo sincronizado. Revisa las cadenas nuevas con scripts/check-strings.py."
