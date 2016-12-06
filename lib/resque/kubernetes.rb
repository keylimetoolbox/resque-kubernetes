require "resque/kubernetes/job"
require "resque/kubernetes/version"
require "resque/kubernetes/worker"
require "resque/kubernetes/configurable"

module Resque
  module Kubernetes
    extend Configurable

    # By default only manage kubernetes jobs in :production
    define_setting :environments, [:production]
  end
end

Resque::Worker.include Resque::Kubernetes::Worker
