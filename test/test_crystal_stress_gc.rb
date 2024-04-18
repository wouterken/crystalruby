# frozen_string_literal: true

require_relative "test_helper"
require "get_process_mem"

class TestCrystalStressGC < Minitest::Test
  module ::GCStress
    crystal lib: "gc_stress_v1" do
      @@leaked_memory = ""
    end

    crystalize [mb: :float] => :void, lib: "gc_stress_v1"
    def gc_stress_v1(mb)
      "a" * (mb * 1024 * 1024).to_i
    end

    crystalize [mb: :float] => :void, lib: "gc_stress_v1"
    def gc_leak_v1(mb)
      @@leaked_memory += "a" * (mb * 1024 * 1024).to_i
    end

    crystalize lib: "gc_stress_v1"
    def gc_free_v1
      @@leaked_memory = ""
    end

    crystalize async: true, lib: "gc_stress_v1"
    def trigger_gc_v1
      GC.collect
    end

    crystal lib: "gc_stress_v2" do
      @@leaked_memory = ""
    end

    crystalize [mb: :float] => :void, lib: "gc_stress_v2"
    def gc_stress_v2(mb)
      "a" * (mb * 1024 * 1024).to_i
    end

    crystalize async: true, lib: "gc_stress_v2"
    def trigger_gc_v2
      GC.collect
    end

    crystalize [mb: :float] => :void, lib: "gc_stress_v2"
    def gc_leak_v2(mb)
      @@leaked_memory += "a" * (mb * 1024 * 1024).to_i
    end

    crystalize lib: "gc_stress_v2"
    def gc_free_v2
      @@leaked_memory = ""
    end
  end

  def test_gc_stress
    if CrystalRuby.config.single_thread_mode
      return # Multi threaded invocation of Crystal code is specific to multi-threaded mode
    end

    10.times.map do
      Thread.new do
        GCStress.gc_stress_v1(100)
        GCStress.gc_stress_v2(100)
        GCStress.gc_leak_v1(25)
        GCStress.gc_leak_v2(25)
        GCStress.trigger_gc_v1
        GCStress.trigger_gc_v2
      end
    end.each(&:join)
    GCStress.gc_free_v1
    GCStress.gc_free_v2
    GCStress.trigger_gc_v1
    GCStress.trigger_gc_v2
  end
end
