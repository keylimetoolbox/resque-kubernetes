# frozen_string_literal: true

lib = File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "resque/kubernetes/version"

Gem::Specification.new do |spec|
  spec.name          = "resque-kubernetes"
  spec.version       = Resque::Kubernetes::VERSION
  spec.authors       = ["Jeremy Wadsack"]
  spec.email         = ["jeremy.wadsack@gmail.com"]

  spec.summary       = "Run Resque Jobs as Kubernetes Jobs"
  spec.description   = "Launches a Kubernetes Job when a Resque Job is enqueued, then " \
                       "terminates the worker when there are no more jobs in the queue."
  spec.homepage      = "https://github.com/keylimetoolbox/resque-kubernetes"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.required_ruby_version = ">= 3.0"

  spec.add_dependency "kubeclient", ">= 4.9.3", "< 5.0"
  spec.add_dependency "resque", ">= 1.26"
  spec.add_dependency "retriable", "~> 3.0"
  spec.metadata["rubygems_mfa_required"] = "true"
end
