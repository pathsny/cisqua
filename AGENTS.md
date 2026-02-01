# Repository Guidelines

## Project Structure & Module Organization
- Ruby app entry points live at `app.rb` and config in `config.rb` / `config/`.
- Core domain logic is under `lib/` (models, processors, API clients, utilities).
- UI assets: `public/` (JS/CSS) and server-rendered templates in `views/`.
- Scripts and ops tasks live in `script/` (setup, post processing, deploy, helpers).
- Tests are split into unit specs in `spec/` and integration-style specs in `integration_spec/`.

## Build, Test, and Development Commands
- Install deps: `bundle install`
- Initial setup: `bundle exec ruby script/setup.rb`
- Run the main post-processing flow: `bundle exec ruby script/post_process.rb`
- Dev server (Sinatra/Puma): `RACK_ENV=development bundle exec ruby app.rb -l`
  - If Redis should start locally, keep `-l`; otherwise omit it.
  - Logs: `data/log/anidb.log` and `data/log/dev.stdout.log`
  - Note: Local Redis binding may require escalated permissions (port 6379). If startup fails, rerun with approval.
  - Error watch (background): `ruby -e 'log=ARGV[0]; out=ARGV[1]; f=File.open(log); f.seek(0,IO::SEEK_END); File.open(out,"a") { |o| loop { if (line=f.gets); if line.include?("\u001b[31mE") || line.match?(/\bERROR\b|\berror\b|Exception|Traceback/); o.write(line); o.flush; end; else; sleep 0.2; end; } }' data/log/dev.stdout.log data/log/dev.errors.log > /dev/null 2>&1 &`
  - Stop error watch: `kill $(cat data/log/dev.error_watch.pid)` (if running)
  - Stop webserver: `lsof -i :4567` then `kill <PID>`
- Run unit specs: `bundle exec ruby spec_runner.rb --pattern './spec/**/*_spec.rb'`
- Run integration specs: `TEST_INTERFACE=cli bundle exec ruby spec_runner.rb --pattern './integration_spec/**/*_spec.rb'`
  - Requires rbenv init: `eval "$(rbenv init -)"`
  - Requires escalated permissions so Redis can bind/connect
- For webserver/web infrastructure changes, run integration specs in web mode:
  - `TEST_INTERFACE=web bundle exec ruby spec_runner.rb --pattern './integration_spec/**/*_spec.rb'`
- Local Docker compose (use local build, avoid re-pull):
  - `cd docker-app && ./build.sh`
  - `docker compose up -d --force-recreate`
  - `docker compose down` to stop
- Frontend formatting/linting (configured in `package.json`):
  - `npx prettier "public/**/*.{js,css}"`
  - `npx stylelint "public/**/*.css"`

## Coding Style & Naming Conventions
- Ruby style follows `.rubocop.yml`; prefer `snake_case` for methods/vars and `CamelCase` for classes/modules.
- JS/CSS live in `public/`; keep filenames descriptive and aligned to views/features.
- Use `spec/` and `integration_spec/` with filenames ending in `_spec.rb`.

## Testing Guidelines
- Framework: RSpec (see `spec/spec_helper.rb` and `integration_spec/spec_helper.rb`).
- Prefer focused unit specs in `spec/lib/**` and broader workflow tests in `integration_spec/`.
- Name examples for behavior and expected outcomes; keep fixtures under `spec/` or `spec_util/`.

## Commit & Pull Request Guidelines
- Commit messages in history are short and descriptive, often lowercase and sometimes prefixed (e.g., `fix:`, `chore:`, `refactor:`). Keep subjects concise and action‑oriented.
- PRs should include: a brief summary, key behavior changes, and screenshots for UI changes in `public/` or `views/`.

## Security & Configuration Tips
- Local credentials and options live under `data/` (e.g., `data/options.yml`); do not commit secrets.
- Be cautious with scripts that touch media folders or external services; prefer dry runs when available.

## Agent-Specific Instructions
- In this repository, commands prefixed with `git` may be run without asking for approval.
- Initialize rbenv before running Ruby/Bundler commands: `eval "$(rbenv init -)"`.
