#!/bin/sh
# Test fake for agent-browser (templates/evidence-capture.example.sh): records each call in
# $AB_LOG and runs nothing. The evidence cases only use the template's dry run, which must call
# no browser at all: any line in $AB_LOG fails them.
printf '%s\n' "$*" >> "${AB_LOG:-/dev/null}"
exit 0
