#!/usr/bin/env bash
# Rebuild the whole University ERP database from the scripts in db/.
#
#   db/rebuild.sh [--db NAME] [--no-seed] [--sample|--no-sample] [--with-tests]
#
# Connection comes from the environment (same names as .env.example):
#   MYSQL_HOST (127.0.0.1)  MYSQL_PORT (3306)  MYSQL_USER (root)  MYSQL_PWD / MYSQL_PASSWORD
# WARNING: drops and recreates the target database.
set -euo pipefail
cd "$(dirname "$0")"

DB="${MYSQL_DATABASE:-university_erp}"; SEED=1; SAMPLE=1; TESTS=0
while [ $# -gt 0 ]; do
  case "$1" in
    --db) DB="$2"; shift ;;
    --no-seed) SEED=0 ;;
    --sample) SAMPLE=1 ;;
    --no-sample) SAMPLE=0 ;;
    --with-tests) TESTS=1 ;;
    *) echo "unknown option $1"; exit 2 ;;
  esac; shift
done
export MYSQL_PWD="${MYSQL_PWD:-${MYSQL_PASSWORD:-}}"
M=(mysql --host="${MYSQL_HOST:-127.0.0.1}" --port="${MYSQL_PORT:-3306}" --user="${MYSQL_USER:-root}" --default-character-set=utf8mb4)

echo "==> (re)creating database $DB"
"${M[@]}" -e "DROP DATABASE IF EXISTS \`$DB\`; CREATE DATABASE \`$DB\` CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;"

run() { echo "    $1"; "${M[@]}" --database="$DB" -e "source $1"; }

echo "==> schema + SQL objects"
for f in 00_admin 01_academics 02_students 03_attendance 04_finance 05_exams 06_placement 07_integration; do run "$f.sql"; done

if [ "$SEED" = 1 ]; then
  echo "==> seed data"
  while read -r kind path; do
    case "$kind" in ''|\#*) continue ;; esac
    if [ "$kind" = sample ] && [ "$SAMPLE" != 1 ]; then continue; fi
    run "$path"
  done < seed/seed_order.txt
fi
if [ "$TESTS" = 1 ]; then
  echo "==> tests"
  for f in tests/*.sql; do run "$f"; done
  "${M[@]}" --database="$DB" --table -e "SELECT module, COUNT(*) AS tests, SUM(outcome='PASS') AS passed, SUM(outcome='FAIL') AS failed FROM test_result GROUP BY module ORDER BY module;"
fi
echo "==> done: $DB"
