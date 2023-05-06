# frozen_string_literal: true

module Resque
  module Kubernetes
    module Context
      # Kubeclient Context from `kubectl` config file.
      class Kubectl
        def applicable?
          File.exist?(kubeconfig)
        end

        # rubocop: disable Metrics/MethodLength
        def context
          config = Kubeclient::Config.read(kubeconfig)

          options = {
              auth_options: auth_options(config),
              ssl_options:  config.context.ssl_options
          }

          Resque::Kubernetes::ContextFactory::Context.new(
            config.context.api_endpoint,
            config.context.api_version,
            config.context.namespace,
            options
          )
        end
        # rubocop: enable Metrics/MethodLength

        private

        def kubeconfig
          File.join(Dir.home, ".kube", "config")
        end

        def auth_options(config)
          options = config.context.auth_options
          return options unless options.empty?

          google_application_default_credentials
        end

        def google_application_default_credentials
          return unless defined?(Google) && defined?(Google::Auth)

          {bearer_token: Kubeclient::GoogleApplicationDefaultCredentials.token}
        end
      end
    end
  end
end
