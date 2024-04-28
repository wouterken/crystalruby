# frozen_string_literal: true

require_relative "../test_helper"

class TestSymbol < Minitest::Test
  crystalize
  def match(a: Symbol(:green, :red, :blue), returns: Symbol(:orange, :yellow, :other))
    case a
    when :green then :orange
    when :red then :yellow
    else :other
    end
  end

  crystalize raw: true
  def count_acknowledgement_statuses(
    statuses: Array(Symbol(%i[acknowledged unacknowledged unknown])),
    returns: Hash(Symbol(%i[acknowledged unacknowledged unknown]), Int32)
  )
    '
    result = statuses.each_with_object({} of Symbol => Int32) do |status, hash|
      hash[status] ||= 0
      hash[status] += 1
    end
    '
  end

  StatusEnum = CRType { Symbol(:active, :inactive) }
  ItemWithStatus = CRType { NamedTuple(status: StatusEnum) }

  crystalize
  def is_active?(status: ItemWithStatus, returns: Bool)
    status.status == :active
  end

  def test_top_level_symbols
    assert match(:green) == :orange
    assert match(:red) == :yellow
    assert match(:blue) == :other
    assert_raises(RuntimeError) { match(:not_found) }
  end

  def test_symbols_in_containers
    assert count_acknowledgement_statuses(
      %i[acknowledged unacknowledged unknown]
    ) == { acknowledged: 1, unacknowledged: 1, unknown: 1 }

    assert count_acknowledgement_statuses(
      %i[acknowledged unacknowledged unknown acknowledged unacknowledged unknown]
    ) == { acknowledged: 2, unacknowledged: 2, unknown: 2 }
  end

  def test_named_symbol_types
    assert_equal true, is_active?(ItemWithStatus.new(status: :active))
    assert_equal false, is_active?(ItemWithStatus.new(status: :inactive))
  end
end
