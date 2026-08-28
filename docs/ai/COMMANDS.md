# Validation commands

The repository uses the official reusable Discourse plugin workflow at `.github/workflows/discourse-plugin.yml`. On pull requests, treat only checks attached to the latest exact PR head SHA as CI evidence.

Expected required gate:
- `Discourse Plugin` workflow: linting plus the applicable Discourse core plugin test matrix
- any additional repository-required Discourse-owned check named `Discourse CI`, if one is configured

Missing, skipped, cancelled, stale-head, or not-run checks are not GREEN.

Run targeted validation from a Discourse checkout with this repository installed under `plugins/discourse-crimson-server-list` when local execution is available:
- One Ruby spec, only if relevant spec exists: `LOAD_PLUGINS=1 bin/rspec plugins/discourse-crimson-server-list/spec/path/to/example_spec.rb`
- Plugin Ruby specs, only if specs exist: `bundle exec rake "plugin:spec[discourse-crimson-server-list]"`
- Plugin QUnit, only if frontend tests exist: `CI=1 bundle exec rake "plugin:qunit[discourse-crimson-server-list]"`
- After plugin migration changes: `LOAD_PLUGINS=1 bundle exec rake db:migrate`

For probe/network changes, validate the narrowest policy/adapter/job surface first, including forbidden-address and timeout/retry behavior where tests exist.
