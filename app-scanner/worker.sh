#!/usr/bin/env bash

set -e
set -x

bundle exec arachni --report-save-path="$1" "$1"
bundle exec arachni_reporter "$1" --reporter=json
