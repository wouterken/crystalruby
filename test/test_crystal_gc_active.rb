# frozen_string_literal: true

require_relative "test_helper"
require "get_process_mem"

class TestcrystalGCActive < Minitest::Test
  module ::GC
    crystal lib: "memory_gobbler", raw: true do
      <<~CRYSTAL
        record Stats,
          heap_size : UInt64,
          free_bytes : UInt64,
          unmapped_bytes : UInt64,
          bytes_since_gc : UInt64,
          total_bytes : UInt64 do
          include JSON::Serializable
        end
      CRYSTAL
    end
  end

  module ::MemoryGobbler
    crystal lib: "memory_gobbler" do
      @@leaked_memory = ""

    end

    crystalize [mb: :float] => :void, lib: "memory_gobbler"
    def gobble_gcable_memory(mb)
      "a" * (mb * 1024 * 1024).to_i
    end

    crystalize [mb: :float] => :void, lib: "memory_gobbler"
    def leak_memory(mb)
      @@leaked_memory += "a" * (mb * 1024 * 1024).to_i
    end

    crystalize [] => json{ Hash(String, Float64) },  async: true, lib: "memory_gobbler"
    def trigger_gc
      5.times do
        sleep 0.001
        GC.collect
      end
      Hash(String, Float64).from_json(GC.stats.to_json)
    end
  end

  def get_memory_increase_mb
    before = GetProcessMem.new
    before_mb, before_inspect = before.mb, before.inspect
    yield
    after = GetProcessMem.new
    after_mb, after_inspect = after.mb, after.inspect
    puts "From: #{before_inspect} to #{after_inspect}"
    after_mb - before_mb
  end

  def test_gc_kicks_in

    baseline_gc_stats = MemoryGobbler.trigger_gc
    100.times do
      MemoryGobbler.leak_memory(0.5)
    end
    leaked_gc_stats = MemoryGobbler.trigger_gc
    assert (leaked_gc_stats['heap_size'] - baseline_gc_stats['heap_size']) / (1024**2) > 50


    baseline_gc_stats = leaked_gc_stats
    100.times do
      MemoryGobbler.gobble_gcable_memory(0.5)
    end
    gc_stats = MemoryGobbler.trigger_gc
    assert (gc_stats['heap_size'] - baseline_gc_stats['heap_size']) / (1024**2) < 10

  end
end
