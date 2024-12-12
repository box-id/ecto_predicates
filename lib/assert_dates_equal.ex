defmodule AssertDatesEqual do
  @moduledoc false
  @unit_millis_breakpoint 20_000_000_000

  @type precision() :: :microsecond | :millisecond | :second

  @doc """
  Asserts that two dates represent the same point in time, parsing values if possible.

  Precision of the comparison can be controlled through `precision` which leads to truncation of the given dates. It
  defaults to `:microsecond` s.t. no precision is lost by default.

  Date parameters can be of formats:
  - `DateTime` struct
  - ISO 8601 string
  - Number which is interpreted as milliseconds since epoch if above #{@unit_millis_breakpoint} or as seconds since
    epoch if below.
  """
  @spec assert_dates_equal(left :: any(), right :: any(), precision :: precision()) :: true
  defmacro assert_dates_equal(left, right, precision \\ :microsecond)

  defmacro assert_dates_equal(left, right, precision) when precision in ~w(microsecond millisecond second)a do
    left_expr = Macro.to_string(left)
    right_expr = Macro.to_string(right)

    quote bind_quoted: [
            left: left,
            right: right,
            left_expr: left_expr,
            right_expr: right_expr,
            precision: precision
          ] do
      with {:left, {:ok, left_date}} <- {:left, parse_date(left)},
           {:right, {:ok, right_date}} <- {:right, parse_date(right)} do
        left_date = DateTime.truncate(left_date, precision)
        right_date = DateTime.truncate(right_date, precision)

        result = DateTime.compare(left_date, right_date)

        if result == :eq do
          assert true
        else
          formatted_result =
            if result == :lt do
              ~s|Left (#{left_expr}) < right (#{right_expr}).|
            else
              ~s|Left (#{left_expr}) > right (#{right_expr}).|
            end

          flunk("""
          Dates do not equal (using #{Atom.to_string(precision)} precision). #{formatted_result}

          #{IO.ANSI.cyan()}left:  #{IO.ANSI.reset()}#{inspect(left_date)}
          #{IO.ANSI.cyan()}right: #{IO.ANSI.reset()}#{inspect(right_date)}
          """)
        end
      else
        {:left, error} -> flunk("Couldn't parse left value #{inspect(left)} to date: #{inspect(error)}")
        {:right, error} -> flunk("Couldn't parse right value #{inspect(left)} to date: #{inspect(error)}")
      end
    end
  end

  def parse_date(%DateTime{} = date), do: {:ok, date}

  def parse_date(date) when is_binary(date) do
    case DateTime.from_iso8601(date) do
      {:ok, date, _offset} -> {:ok, date}
      {:error, reason} -> reason
    end
  end

  def parse_date(date) when is_integer(date) do
    unit = if(date > @unit_millis_breakpoint, do: :millisecond, else: :second)

    DateTime.from_unix(date, unit)
  end
end
