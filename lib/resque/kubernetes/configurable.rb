# frozen_string_literal: true

module Resque
  module Kubernetes
    # Provides configuration settings, with default values, for the gem.
    module Configurable
      def configuration
        yield self
      end

      # Define a configuration setting and its default value.
      #
      # name:    The name of the setting.
      # default: A default value for the setting. (Optional)
      # rubocop: disable Style/ClassVars
      def define_setting(name, default = nil)
        class_variable_set("@@#{name}", default)

        define_class_method "#{name}=" do |value|
          class_variable_set("@@#{name}", value)
        end

        define_class_method name do
          class_variable_get("@@#{name}")
        end
      end
      # rubocop: enable Style/ClassVars

      private

      def define_class_method(name, &block)
        (class << self; self; end).instance_eval do
          define_method(name, &block)
        end
      end
    end
  end
end
