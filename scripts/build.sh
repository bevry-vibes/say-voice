#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$ROOT"

swift build -c release

SCRIPT="$ROOT/.build/say-voice.swift"
{
	cat Sources/SayVoiceCore/VoiceOption.swift
	cat Sources/SayVoiceCore/VoiceCatalog.swift
	cat Sources/SayVoiceCore/VoiceMatcher.swift
	cat Sources/SayVoiceCore/DefaultVoice.swift
	cat Sources/SayVoiceCore/Speaker.swift
	sed '/^import SayVoiceCore$/d' Sources/SayVoiceCLI/main.swift
} > "$SCRIPT"

echo "Binary: $ROOT/.build/release/say-voice"
echo "Script: $SCRIPT"
echo "The script is the supported command for Siri natural voices."
