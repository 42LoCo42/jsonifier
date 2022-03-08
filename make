#!/usr/bin/env bash
cd "$(dirname "${BASH_SOURCE[0]}")" || exit 1

sourceDir="src"
targetDir="converters"

mkdir -p "$targetDir"

find "$sourceDir" -type f | while read -r file; do
	case "${file##*.}" in
		nim) nim c -d:release --outdir:"$targetDir" "$file"  ;;
		*) cp "$file" "$targetDir"
	esac
done
