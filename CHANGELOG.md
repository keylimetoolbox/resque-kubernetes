# 0.8.0
- Fix bug where enqueueing jobs would keep adding workers if worker count
  was _greater_ than `max_workers`
# 0.7.0
- Update to support kubeclient 2.2 or 3.x
# 0.6.0
- Add support for ActiveJob when configured to be backed by Resque
- When authorizing with `~/.kube/config` use Google Default Application Credentials rather than require a
  forked version of `kubeclient`
# 0.5.0
- Maximum workers can no be configured per job type
- Fix a crash when cleaning up a job that was removed by another process
- No longer clean up pods because cleaning up finished jobs takes care of that
- Apply rubocop, and bundler-audit rules

# 0.4.0
- Syntax error fix

# 0.3.0
- Syntax error fix

# 0.2.0
- Fix for running in GKE cluster and production Rails environment

# 0.1.0
- Initial release
