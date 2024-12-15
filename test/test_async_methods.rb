# frozen_string_literal: true

require_relative "test_helper"
require "benchmark"
class TestAsyncMethods < Minitest::Test
  module Sleeper
    crystallize async: true
    def sleep_async(a: :float)
      sleep(a.seconds)
    end

    crystallize async: false
    def sleep_sync(a: :float)
      sleep(a.seconds)
    end
  end

  def test_sync_sleep_is_serial_async_concurrent
    # Multi threaded invocation of Crystal code is specific to multi-threaded mode
    return if CrystalRuby.config.single_thread_mode

    total_sleep_time = Benchmark.realtime do
      5.times.map do
        Thread.new do
          Sleeper.sleep_sync(0.2)
        end
      end.each(&:join)
    end
    assert total_sleep_time > 1

    total_sleep_time = Benchmark.realtime do
      5.times.map do
        Thread.new do
          Sleeper.sleep_async(0.2)
        end
      end.each(&:join)
    end
    assert total_sleep_time < 0.5
  end

  crystallize async: true
  def callback_ruby(returns: Int32)
    ruby_callback() + ruby_callback()
  end

  expose_to_crystal
  def ruby_callback(returns: Int32)
    10
  end

  def test_can_callback_ruby_from_async
    assert_equal callback_ruby, 20
  end

  crystallize async: true
  def yield_to_ruby(yield: Proc(Int32, Nil))
    yield 10
    yield 20
    yield 30
  end

  def test_can_yield_to_ruby_from_async
    yielded = []
    yield_to_ruby do |val|
      yielded << val
    end

    assert_equal yielded, [10, 20, 30]
  end
end
