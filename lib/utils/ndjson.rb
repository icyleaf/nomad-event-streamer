require "active_support"
require "active_support/core_ext"
require "json"

class NDJSON
  def self.parse(partial)
    new.parse_partial(partial)
  end

  def initialize
    @previous_part = ""
  end

  def parse_partial(partial)
    wholes = []

    # We know the JSON begins and ends based on new lines cause it's NDJSON format
    parts = partial.split("\n", -1).reject(&:empty?)

    parts.each_with_index do |part, index|
      unless index.zero?
        wholes << @previous_part

        @previous_part = ""
      end

      @previous_part << part
    end

    wholes
      .map do |whole|
        JSON.parse(whole)
      rescue JSON::ParserError
        # Could be incomplete JSON cause it was the tail or head
        nil
      end
      .compact
  end
end
