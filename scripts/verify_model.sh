#!/bin/bash
EXPECTED_SHA="UNSPECIFIED"
ACTUAL_SHA=$(sha256sum downloads/Bonsai-1.7B-Q1_0.gguf | awk "{print \$1}")
if [ "$EXPECTED_SHA" = "UNSPECIFIED" ]; then
  echo "Expected checksum not provided; actual SHA: $ACTUAL_SHA"
else
  if [ "$ACTUAL_SHA" != "$EXPECTED_SHA" ]; then
    echo "ERROR: Model checksum mismatch!"
    exit 1
  fi
fi
