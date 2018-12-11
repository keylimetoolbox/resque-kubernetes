# frozen_string_literal: true

module Resque
  module Kubernetes
    # Wraps Kubeclient::Client to retry timeout errors
    class RetriableClient
      attr_accessor :kubeclient

      def initialize(client)
        self.kubeclient = client
      end

      def method_missing(method, *args, &block)
        if kubeclient.respond_to?(method)
          Retriable.retriable(on: {Kubeclient::HttpError => /Timed out/}) do
            kubeclient.send(method, *args, &block)
          end
        else
          super
        end
      end

      def respond_to_missing?(method)
        kubeclient.respond_to?(method)
      end
    end
  end
end
