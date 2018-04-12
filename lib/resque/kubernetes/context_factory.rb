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
          auth_options = config.context.auth_options

          auth_options = google_default_application_credentials(config) if auth_options.empty?

          Kubeclient::Config::Context.new(
              config.context.api_endpoint,
              config.context.api_version,
              config.context.ssl_options,
              auth_options
          )
        end

        def kubeconfig
          File.join(ENV["HOME"], ".kube", "config")
        end

        # TODO: Move this logic to kubeclient. See abonas/kubeclient#213
        def google_default_application_credentials(config)
          return unless defined?(Google) && defined?(Google::Auth)

          _cluster, user = config.send(:fetch_context, config.instance_variable_get(:@kcfg)["current-context"])
          return {} unless user["auth-provider"] && user["auth-provider"]["name"] == "gcp"

          {bearer_token: new_google_token}
        end

        def new_google_token
          scopes = ["https://www.googleapis.com/auth/cloud-platform"]
          authorization = Google::Auth.get_application_default(scopes)
          authorization.apply({})
          authorization.access_token
        end
      end
    end
  end
end
