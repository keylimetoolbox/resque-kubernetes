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
        # n: The number of characters to return (default 5).
        def random_chars(n = 5)
          s = [SecureRandom.random_bytes(n)].pack("m*")
          s.delete!("=\n")
          s.tr!("+/_-", "0")
          s.tr!("A-Z", "a-z")
          s[0...n]
        end
      end
    end
  end
end
