#!/bin/bash
# Launch GetUp - native Swift menu bar app
DIR="$(cd "$(dirname "$0")" && pwd)"
open "$DIR/dist/GetUp.app"
