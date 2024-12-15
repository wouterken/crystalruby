# frozen_string_literal: true

require_relative "test_helper"
require "benchmark"
require "crystalruby"

class TestPerformance < Minitest::Test
  module PrimeCounter

    crystallize
    def count_primes_upto_cr n: :int32, returns: :int32
      (2..n).each.count do |i|
        is_prime = true
        (2..Math.sqrt(i).to_i).each do |j|
          if i % j == 0
            is_prime = false
            break
          end
        end
        is_prime
      end
    end
  end

  include PrimeCounter
  def test_performance
    count_primes_upto_cr(0) # Compile
    assert Benchmark.realtime {
      count_primes_upto_cr(1_000_000)
    } < 2 # Not a robust test. May fail on older or emulated devices
  end
end
