# frozen_string_literal: true

module Resque
  module Kubernetes
    # A subclass of Hash that allows nested keys to be added
    # and ensures the interim hashes exist.
    class DeepHash < Hash
      # Add keys and a value to nested hashes.
      #
      # keys:  An array of keys.
      # value: A value to assign to the key in the ultimate hash.
      #
      # Example:
      #     h = DeepHash.new
      #     h.deep_add(%w[one two three], "deep")
      #     deep = h["one"]["two"]["three"]
      def deep_add(keys, value)
        last_key = keys.pop

        m = self
        keys.each do |key|
          m[key] ||= {}
          m = m[key]
        end

        m[last_key] = value

        m
      end
    end
  end
end
