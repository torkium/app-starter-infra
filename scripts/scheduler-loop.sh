#!/usr/bin/env sh
set -eu

tick_command="${SCHEDULER_TICK_COMMAND:-php bin/console app:schedule:run}"
sleep_seconds="${SCHEDULER_SLEEP_SECONDS:-60}"

while true; do
  sh -lc "$tick_command"
  sleep "$sleep_seconds"
done
