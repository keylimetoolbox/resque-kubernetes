# frozen_string_literal: true

require "kubeclient"

module Resque
  module Kubernetes
    # Create a context for `Kubeclient` depending on the environment.
    class ContextFactory
      class << self
        def context
          # TODO: Add ability to load this from config

          if File.exist?("/var/run/secrets/kubernetes.io/serviceaccount/token")
            # When running in GKE/k8s cluster, use the service account secret token and ca bundle
            well_known_context
          elsif File.exist?(kubeconfig)
            # When running in development, use the config file for `kubectl` and default application credentials
            kubectl_context
          end
        end

        private

        def well_known_context
          Kubeclient::Config::Context.new(
              "https://kubernetes",
              "v1",
              {ca_file: "/var/run/secrets/kubernetes.io/serviceaccount/ca.crt"},
              bearer_token_file: "/var/run/secrets/kubernetes.io/serviceaccount/token"
          )
        end

        def kubectl_context
          config = Kubeclient::Config.read(kubeconfig)
          Kubeclient::Config::Context.new(
              config.context.api_endpoint,
              config.context.api_version,
              config.context.ssl_options,
              use_default_gcp: true
          )
        end

        def kubeconfig
          File.join(ENV["HOME"], ".kube", "config")
        end
      end
    end
  end
end
