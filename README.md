# Resque::Kubernetes

Run Resque Jobs as Kubernetes Jobs!

Kubernetes has a concept of "Job" which is a pod that runs a container until
the container finishes and then it terminates the pod (as opposed to trying to
restart the container).

This gem takes advantage of that feature by starting up a Kubernetes Job when 
a Resque Job is enqueued. It then allows the Resque Worker to be modified to 
terminate when there are no more jobs in the queue.

Why would you do this?

We have unpredictable, resource-intensive jobs. Rather than dedicating large 
nodes in our cluster to run the resque workers, where the resources would be 
idle when there are no jobs to run, we can use autoscaling to add nodes when
Kubernetes Job gets created and shut them down when those jobs are complete. 

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'resque-kubernetes'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install resque-kubernetes

## Usage

For any Resque job that you want to run in a Kubernetes pod, you'll need to
modify the job class with three things:

- extend the class with `Resque::Kubernetes::Job`
- and add a method `job_manifest` that returns the Kubernetes manifest for the job
- make sure that the worker is started with `TERM_ON_EMPTY` environment variable set

```ruby
class ResourceIntensiveJob
  extend Resque::Kubernetes::Job
  
  def perform
    # ... your existing code
  end
  
  def job_manifest
    <<-EOD
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
        - name: TERM_ON_EMPTY
          value: 1
    EOD
  end
end
```
The `TERM_ON_EMPTY` environment variable is critical for the flow. This tells 
this worker that whenever the queue is empty is should terminate the worker.
Kubernetes will then terminate the Job when the container is done running and
will release the resources.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, 
run `rake spec` to run the tests. You can also run `bin/console` for an 
interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. 
To release a new version, update the version number in `version.rb`, and then 
run `bundle exec rake release`, which will create a git tag for the version, 
push git commits and tags, and push the `.gem` file to 
[rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at 
https://github.com/keylime-toolbox/resque-kubernetes.


## License

The gem is available as open source under the terms of the 
[MIT License](http://opensource.org/licenses/MIT).

