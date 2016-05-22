cd web && bundle exec rerun --pattern "**/*.{rb,erb}" \
  --ignore public/ \
  "bundle exec puma -b tcp://0.0.0.0:9393 config.ru"
  --restart