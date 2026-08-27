# Validation commands

Run from a Discourse checkout with this repository installed under `plugins/discourse-crimson-server-list`.

- One Ruby spec, only if relevant spec exists: `LOAD_PLUGINS=1 bin/rspec plugins/discourse-crimson-server-list/spec/path/to/example_spec.rb`
- Plugin Ruby specs, only if specs exist: `bundle exec rake "plugin:spec[discourse-crimson-server-list]"`
- Plugin QUnit, only if frontend tests exist: `CI=1 bundle exec rake "plugin:qunit[discourse-crimson-server-list]"`
- After plugin migration changes: `LOAD_PLUGINS=1 bundle exec rake db:migrate`

No `.github/workflows` directory was present on `main` when created (2026-08-27). Do not call CI GREEN unless an exact-head workflow/check actually exists and ran.

For probe/network changes, validate the narrowest policy/adapter/job surface first, including forbidden-address and timeout/retry behavior where tests exist.
