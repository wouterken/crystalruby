# frozen_string_literal: true

require_relative "test_helper"

class TestGCStress < Minitest::Test
  module ::GCStress
    crystal lib: "gc_stress_v1" do
      @@leaked_memory = ""
    end

    crystallize async: true, lib: "gc_stress_v1"
    def gc_stress_v1(mb: :float)
      "a" * (mb * 1024 * 1024).to_i
    end

    crystallize async: true, lib: "gc_stress_v1"
    def gc_leak_v1(mb: :float)
      @@leaked_memory += "a" * (mb * 1024 * 1024).to_i
    end

    crystallize lib: "gc_stress_v1"
    def gc_free_v1
      @@leaked_memory = ""
    end

    crystallize async: true, lib: "gc_stress_v1"
    def trigger_gc_v1
      GC.collect
    end

    crystal lib: "gc_stress_v2" do
      @@leaked_memory = ""
    end

    crystallize lib: "gc_stress_v2"
    def gc_stress_v2(mb: :float)
      "a" * (mb * 1024 * 1024).to_i
    end

    crystallize async: true, lib: "gc_stress_v2"
    def trigger_gc_v2
      GC.collect
    end

    crystallize lib: "gc_stress_v2"
    def gc_leak_v2(mb: :float)
      @@leaked_memory += "a" * (mb * 1024 * 1024).to_i
    end

    crystallize lib: "gc_stress_v2"
    def gc_free_v2
      @@leaked_memory = ""
    end
  end

  LOG_STEPS = false

  def test_gc_stress
    # Multi threaded invocation of Crystal code is specific to multi-threaded mode
    return if CrystalRuby.config.single_thread_mode

    10.times.map do |i|
      puts "Iteration #{i} GC stress v1" if LOG_STEPS
      GCStress.gc_stress_v1(100)
      puts "Iteration #{i} GC stress v1 DONE." if LOG_STEPS

      puts "Iteration #{i} GC stress v2" if LOG_STEPS
      GCStress.gc_stress_v2(100)
      puts "Iteration #{i} GC stress v2 DONE." if LOG_STEPS

      Thread.new do
        puts "Thread #{i} gc v1" if LOG_STEPS
        GCStress.gc_stress_v1(100)
        puts "Thread #{i} gc v2" if LOG_STEPS
        GCStress.gc_stress_v2(100)
        puts "Thread #{i} gc leak v1" if LOG_STEPS
        GCStress.gc_leak_v1(25)
        puts "Thread #{i} gc leak v2" if LOG_STEPS
        GCStress.gc_leak_v2(25)
        puts "Thread #{i} gc trigger v1" if LOG_STEPS
        GCStress.trigger_gc_v1
        puts "Thread #{i} gc trigger v2" if LOG_STEPS
        GCStress.trigger_gc_v2
      end
    end.each(&:join)
    puts "Main thread gc free v1" if LOG_STEPS
    GCStress.gc_free_v1
    puts "Main thread gc free v2" if LOG_STEPS
    GCStress.gc_free_v2
    puts "Main gc trigger v1" if LOG_STEPS
    GCStress.trigger_gc_v1
    puts "Main gc trigger v2" if LOG_STEPS
    GCStress.trigger_gc_v2
  end
end
