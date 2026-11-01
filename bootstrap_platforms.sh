#!/usr/bin/env bash
set -euo pipefail

# Run from the MedQuest project root. This generates fresh platform runners
# using the MedQuest application identifier rather than Anatomo's identifier.
flutter create --project-name medquest --org fr.medquest --platforms=android,ios .
