# frozen_string_literal: true

require "securerandom"

module Resque
  module Kubernetes
    # Simple utility to generate a string of DNS-safe characters.
    #
    # Example:
    #     str = DNSSafeRandom.random_characters
    class DNSSafeRandom
      class << self
        # Returns an n-length string of DNS-safe characters.
        #
        # number: The number of characters to return (default 5).
        def random_chars(number = 5)
          s = [SecureRandom.random_bytes(number)].pack("m*")
          s.delete!("=\n")
          s.tr!("+/_-", "0")
          s.tr!("A-Z", "a-z")
          s[0...number]
        end
      end
    end
  end
end
