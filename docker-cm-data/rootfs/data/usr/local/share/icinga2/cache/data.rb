# frozen_string_literal: true

module Cache

  class Data

    attr_reader :value
    attr_reader :expiresIn

    def initialize( value, expiresIn: nil )
      @value = value
      @expires_in = expiresIn.nil? ? nil : Time.now + expiresIn
    end

    def expired?
      !@expires_in.nil? && Time.now > @expires_in
    end

    def ==(other)
      other.is_a?(Cache::Data) && @value == other.value
    end
  end
end
