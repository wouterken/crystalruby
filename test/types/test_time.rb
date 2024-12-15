# frozen_string_literal: true

require_relative "../test_helper"

class TestTime < Minitest::Test
  class TimeClass < CRType { Time }
  end

  def test_it_acts_like_a_time
    tm = TimeClass.new(0)
    assert_equal tm, Time.at(0)
  end

  def test_it_can_turn_into_a_timestamp
    tm = TimeClass.new
    assert (tm.to_f - Time.now.to_f) >= -1
  end

  crystallize
  def time_diff(time1: Time, time2: Time, returns: Float64)
    (time1 - time2).to_f
  end

  crystallize
  def one_day_from(time: Time, returns: Time)
    time + (24 * 60 * 60).seconds
  end

  def test_it_can_do_time_math
    assert_equal time_diff(Time.at(100), Time.at(50)), 50.0
    assert_equal one_day_from(Time.at(0)), Time.at(24 * 60 * 60)
  end
end
