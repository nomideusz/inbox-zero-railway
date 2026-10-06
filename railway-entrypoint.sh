#!/bin/sh
set -e

# Postgres is often still starting on a fresh Railway deploy. Upstream start.sh
# logs a failed migration and boots anyway, leaving an app with no tables, so
# retry here until migrations go through, then let start.sh skip them.
i=0
until /app/docker/scripts/migrate.sh; do
  i=$((i + 1))
  [ "$i" -ge 30 ] && { echo "Database migrations failed 30 times, giving up"; exit 1; }
  echo "Retrying migrations in 5s ($i/30)..."
  sleep 5
done
export SKIP_DB_MIGRATIONS=true

# Upstream compose runs a separate cron container that curls these endpoints in
# loops. Run the same loops in here against this container, so the template
# needs no extra service.
cron() { # <path> <interval seconds>
  # start.sh's placeholder rewrite can take a minute or two before the server listens
  until wget -q -O /dev/null "http://127.0.0.1:${PORT:-3000}/api/health"; do sleep 10; done
  while :; do
    wget -q -O /dev/null --header "Authorization: Bearer $CRON_SECRET" \
      "http://127.0.0.1:${PORT:-3000}$1" || echo "[cron] $1 failed"
    sleep "$2"
  done
}
if [ -n "$CRON_SECRET" ]; then
  cron /api/cron/scheduled-actions 900 &
  cron /api/cron/automation-jobs 900 &
  cron /api/follow-up-reminders 3600 &
  cron /api/resend/digest/all 1800 &
  cron /api/meeting-briefs 900 &
  cron /api/meeting-recorder/schedule 300 &
  cron /api/watch/all 21600 &
fi

exec /app/docker/scripts/start.sh
