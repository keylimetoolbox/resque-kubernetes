require "resque/kubernetes/job"
require "resque/kubernetes/version"
require "resque/kubernetes/worker"
require "resque/kubernetes/configurable"

module Resque
  module Kubernetes
    extend Configurable

    # By default only manage kubernetes jobs in :production
    define_setting :environments, [:production]

    # Limit the number of workers that should be spun up, default 10
    define_setting :max_workers, 10
  end
end

Resque::Worker.include Resque::Kubernetes::Worker
