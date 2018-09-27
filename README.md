# Resque::Kubernetes

Run Resque (and ActiveJob) Workers as Kubernetes Jobs!

Kubernetes has a concept of "Job" which is a pod that runs a container until
the container finishes and then it terminates the pod (as opposed to trying to
restart the container).

This gem takes advantage of that feature by starting up a Kubernetes Job to
run a worker when a Resque job or ActiveJob is enqueued. It then allows the
Resque worker to be modified to terminate when there are no more jobs in the queue.

Why would you do this?

We have unpredictable, resource-intensive jobs. Rather than dedicating large 
nodes in our cluster to run the resque workers, where the resources would be 
idle when there are no jobs to run, we can use auto-scaling to add nodes when
a Kubernetes Job gets created and shut them down when those jobs are complete. 

## Installation

Add this line to your application's Gemfile:

```ruby
gem "resque-kubernetes"
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install resque-kubernetes

## Usage

This works with native/pure Resque jobs and with ActiveJob _backed by Resque_.
Under ActiveJob, the workers are still Resque workers, so the same set up 
applies. You just configure the job class differently.

### Pure Resque

For any Resque job that you want to run in a Kubernetes job, you'll need
to modify the class with two things:

- `extend` the class with `Resque::Kubernetes::Job`
- add a class method `job_manifest` that returns the Kubernetes manifest for the job
  as a `Hash`

```ruby
class ResourceIntensiveJob
  extend Resque::Kubernetes::Job

  class << self
    def perform
      # ... your existing code
    end

    def job_manifest
      YAML.safe_load(
        <<~MANIFEST
          apiVersion: batch/v1
          kind: Job
          metadata:
            name: worker-job
          spec:
            template:
              metadata:
                name: worker-job
              spec:
                containers:
                - name: worker
                  image: us.gcr.io/project-id/some-resque-worker
                  env:
                  - name: QUEUE
                    value: high-memory
        MANIFEST
      )
    end
  end
end
```

### ActiveJob (on Resque)

For any ActiveJob that you want to run in a Kubernetes job, you'll need to
modify the class with two things:

- `include` `Resque::Kubernetes::Job` in the class
- add an instance method `job_manifest` that returns the Kubernetes manifest for the job
  as a `Hash`

```ruby
class ResourceIntensiveJob < ApplicationJob
  include Resque::Kubernetes::Job

  def perform
    # ... your existing code
  end

  def job_manifest
    YAML.safe_load(
      <<~MANIFEST
        apiVersion: batch/v1
        kind: Job
        metadata:
          name: worker-job
        spec:
          template:
            metadata:
              name: worker-job
            spec:
              containers:
              - name: worker
                image: us.gcr.io/project-id/some-resque-worker
                env:
                - name: QUEUE
                  value: high-memory
      MANIFEST
    )
  end
end
```

### Workers (for both)

Make sure that the container image above, which is used to run the resque 
worker, is built to include the `resque-kubernetes` gem as well. The gem will 
add `TERM_ON_EMPTY` to the environment variables. This tells the worker that 
whenever the queue is empty it should terminate the worker. Kubernetes will 
then terminate the Job when the container is done running and will release the 
resources.

### Job manifest

In the example above we show the manifest as a HEREDOC, just to make it
simple. But you could also read this from a file, parse a template and insert
values, or anything else you want to do in the method, as long as you return
a valid Kubernetes Job manifest as a `Hash`.

## Configuration

You can modify the configuration of the gem by creating an initializer in
your project:

```ruby
# config/initializers/resque-kubernetes.rb

Resque::Kubernetes.configuration do |config|
 config.environments << "staging"
 config.max_workers = 10
end
```

### `environments`

> This only works under Rails, when `Rails.env` is set.

By default `Resque::Kubernetes` will only manage Kubernetes Jobs in
`:production`. If you want to add other environments you can update this list
(`config.environments << "staging"`) or replace it (`config.environments =
["production", "development"]`).

### `max_workers`

`Resque::Kubernetes` will spin up a Kuberentes Job each time you enqueue a 
Resque Job. This allows for parallel processing of jobs using the resources
available to your cluster. By default this is limited to 10 workers, to prevent 
run-away cloud resource usage.

You can set this higher if you need massive scaling and your structure supports
it.

If you don't want more than one job running at a time then set this to 1.

Beyond this global scope you can adjust the total number of workers on each
individual Resque Job type by overriding the `max_workers` method for the job.
If you change this, the value returned by that method takes precedence over the
global value.

```ruby
class ResourceIntensiveJob
  extend Resque::Kubernetes::Job

  class << self
    def perform
      # ...
    end

    def job_manifest
      # ...
    end

    def max_workers
      # Simply return an integer value, or do something more complicated if needed.
      105
    end
  end
end
```

### kubeclient

The gem will automatically connect to the Kubernetes server in the following cases:
- You are running this in [a standard Kubernetes cluster](https://kubernetes.io/docs/tasks/access-application-cluster/access-cluster/#accessing-the-api-from-a-pod)
- You are running on a system with `kubeclient` installed and
  - the default cluster context has credentials
  - the default cluster is GKE and your system has 
    [Google application default credentials](https://developers.google.com/identity/protocols/application-default-credentials)
    installed

There are many other ways to connect and you can do so by providing your own
[configured `kubeclient`](https://github.com/abonas/kubeclient#usage):

```ruby
# config/initializers/resque-kubernetes.rb

Resque::Kubernetes.configuration do |config|
 config.kubeclient = Kubeclient::Client.new("http://localhost:8080/apis/batch")
end
```

Because this uses the `Job` resource, make sure to connect to the `/apis/batch` API endpoint in your client.

## Contributing

Bug reports and pull requests are welcome on GitHub at
https://github.com/keylime-toolbox/resque-kubernetes.

1. Fork it (`https://github.com/[my-github-username]/resque-kubernetes/fork`)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Test your changes with `rake`, add new tests if needed
4. Commit your changes (`git commit -am 'Add some feature'`)
6. Push to the branch (`git push origin my-new-feature`)
7. Open a new Pull Request


### Development

After checking out the repo, run `bin/setup` to install dependencies. Then, 
run `rake` to run the test suite.

You can run `bin/console` for an interactive prompt that will allow you to
experiment.

Write test for any code that you add. Test all changes by running `rake`.
This does the following, which you can also run separately while working.
1. Run unit tests: `appraisal rake spec`
2. Make sure that your code matches the styles: `rubocop`
3. Verify if any dependent gems have open CVEs (you must update these):
   `rake bundle:audit` 

### End to End Tests

We don't run End to End (e2e) tests in the regular suite because
they require a connection to a cluster. You should run these on your changes
to verify that the jobs are created correctly.

This will use the default authentication on your system, which is either
the cluster the tests are running in (if you are doing that), your `kubclient`
configuration, or your Google Default Application Credentials.

```bash
rspec --tag type:e2e
```

## Release

To release a new version, update the version number in
`lib/resque/kubernetes/version.rb` and the `CHANGELOG.md`, then run
`bundle exec rake release`, which will create a git tag for the version,
push git commits and tags, and push the `.gem` file to 
[rubygems.org](https://rubygems.org).

## License

The gem is available as open source under the terms of the 
[MIT License](http://opensource.org/licenses/MIT).

