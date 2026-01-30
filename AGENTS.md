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
- Run unit specs: `bundle exec ruby spec_runner.rb --pattern './spec/**/*_spec.rb'`
- Run integration specs: `TEST_INTERFACE=cli bundle exec ruby spec_runner.rb --pattern './integration_spec/**/*_spec.rb'`
  - Requires rbenv init: `eval "$(rbenv init -)"`
  - Requires escalated permissions so Redis can bind/connect
- For webserver/web infrastructure changes, run integration specs in web mode:
  - `TEST_INTERFACE=web bundle exec ruby spec_runner.rb --pattern './integration_spec/**/*_spec.rb'`
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
