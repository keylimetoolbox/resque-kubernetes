# frozen_string_literal: true

require "resque"

module Resque
  module Kubernetes
    # Patches the resque worker to terminate when the queue is empty.
    #
    # This patch enables setting an environment variable, `TERM_ON_EMPTY`
    # that causes the worker to shutdown when the queue no longer has any
    # resque jobs. This allows running workers as Kuberenetes Jobs that will
    # terminate when there is no longer any work to do.
    #
    # To use, make sure that the container images that hold your workers are
    # built to include the `resque-kubernetes` gem and set `TERM_ON_EMPTY` in
    # their environment to a truthy value (e.g. "1").
    module Worker
      def self.included(base)
        base.class_eval do
          prepend InstanceMethods
        end
      end

      attr_accessor :term_on_empty

      # Replace methods on the worker instance
      module InstanceMethods
        def prepare
          self.term_on_empty = ENV["TERM_ON_EMPTY"] if ENV["TERM_ON_EMPTY"]
          super
        end

        def shutdown?
          if term_on_empty
            if queues_empty?
              log_with_severity :info, "shutdown: queues are empty"
              shutdown
            end
          end

          super
        end
      end

      private

      def queues_empty?
        queues.all? { |queue| Resque.size(queue).zero? }
      end
    end
  end
end
