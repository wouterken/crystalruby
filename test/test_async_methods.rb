# frozen_string_literal: true

require_relative "test_helper"
require "benchmark"
class TestAsyncMethods < Minitest::Test
  module Sleeper
    crystalize [a: :float] => :void, async: true
    def sleep_async(a)
      sleep(a)
    end

    crystalize [a: :float] => :void, async: false
    def sleep_sync(a)
      sleep(a)
    end
  end

  def test_sync_sleep_is_serial
    if CrystalRuby.config.single_thread_mode
      return # Multi threaded invocation of Crystal code is specific to multi-threaded mode
    end

    total_sleep_time = Benchmark.realtime do
      5.times.map do
        Thread.new do
          Sleeper.sleep_sync(0.2)
        end
      end.each(&:join)
    end
    assert total_sleep_time > 1
  end

  def test_async_sleep_is_concurrent
    if CrystalRuby.config.single_thread_mode
      return # Multi threaded invocation of Crystal code is specific to multi-threaded mode
    end

    total_sleep_time = Benchmark.realtime do
      5.times.map do
        Thread.new do
          Sleeper.sleep_async(0.2)
        end
      end.each(&:join)
    end
    assert total_sleep_time < 0.5
  end
end
