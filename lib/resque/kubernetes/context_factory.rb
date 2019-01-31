# frozen_string_literal: true

require "kubeclient"

module Resque
  module Kubernetes
    # Create a context for `Kubeclient` depending on the environment.
    class ContextFactory
      Context = Struct.new(:endpoint, :version, :namespace, :options)

      class << self
        def context
          [
              Resque::Kubernetes::Context::WellKnown,
              Resque::Kubernetes::Context::Kubectl
          ].each do |context_type|
            context = context_type.new
            return context.context if context.applicable?
          end

          nil
        end
      end
    end
  end
end
