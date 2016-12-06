# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'resque/kubernetes/version'

Gem::Specification.new do |spec|
  spec.name          = "resque-kubernetes"
  spec.version       = Resque::Kubernetes::VERSION
  spec.authors       = ["Jeremy Wadsack"]
  spec.email         = ["jeremy.wadsack@gmail.com"]

  spec.summary       = %q{Run Resque Jobs as Kubernetes Jobs}
  spec.description   = %q{Launches a Kubernetes Job when a Resque Job is enqueued, then terminates the worker when there are no more jobs in the queue.}
  spec.homepage      = "https://github.com/keylimetoolbox/resque-kubernetes"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.13"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"

  spec.add_dependency "resque", "~> 1.26"
  spec.add_dependency "kubeclient", "~> 2.2"
end
