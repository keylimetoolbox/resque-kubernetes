# (Unreleased)
**Breaking Change:**
- The `environments` configuration as been replaced by a more flexible `enabled` properties.

Here's how to migrate from the `environments` property to the `enabled` property:

Before:
```ruby
# config/initializers/resque-kubernetes.rb

Resque::Kubernetes.configuration do |config|
 config.environments << "staging"
 config.max_workers = 10
end
```

After:
```ruby
# config/initializers/resque-kubernetes.rb

Resque::Kubernetes.configuration do |config|
 config.enabled     = Rails.env.production? || Rails.env.staging?
 config.max_workers = 10
end
```

⚠️ By default, this gem is not enabled.

- Allow resque 2.0 but retain support for 1.26 or later

# v1.3.0
- Retry when a timeout occurs connecting to the Kubernetes API server

# v1.2.0
- Clean up finished pods that have successfully completed

# v1.1.0
- Fix design to set `INTERVAL=0` for the worker in the Kubernetes
  job manifest, which tells `resque` to work until there are no more jobs,
  rather than monkey-patching `Resque::Worker` to look for `TERM_ON_EMPTY`
  environment variable.

# v1.0.0
**Breaking Change:**
- Requires `kubeclient` 3.1.2 or 4.x

**Changes:**
- Add `kubeclient` configuration option for connecting to any Kubernetes server
- Use kubernetes namespace provided by cluster or `kubectl` configuration when available
- Add Appraisal for testing with kubeclient 3.1.2 and 4.x

# v0.10.0
- `kubeclient` may not be later than 3.0.0 due to change in signature of `Kubeclient::Config::Context#initialize`
  in `kubeclient` 3.1.0

# v0.9.0
- Update to not pollute the job class with our methods

# v0.8.0
- Fix bug where enqueueing jobs would keep adding workers if worker count
  was _greater_ than `max_workers`

# v0.7.0
- Update to support kubeclient 2.2 or 3.x

# v0.6.0
- Add support for ActiveJob when configured to be backed by Resque
- When authorizing with `~/.kube/config` use Google Default Application Credentials rather than require a
  forked version of `kubeclient`

# v0.5.0
- Maximum workers can no be configured per job type
- Fix a crash when cleaning up a job that was removed by another process
- No longer clean up pods because cleaning up finished jobs takes care of that
- Apply rubocop, and bundler-audit rules

# v0.4.0
- Syntax error fix

# v0.3.0
- Syntax error fix

# v0.2.0
- Fix for running in GKE cluster and production Rails environment

# v0.1.0
- Initial release
