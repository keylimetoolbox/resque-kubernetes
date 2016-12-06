require "resque/kubernetes/job"
require "resque/kubernetes/version"
require "resque/kubernetes/worker"

module Resque
  module Kubernetes
  end
end

Resque::Worker.include Resque::Kubernetes::Worker
