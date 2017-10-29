# frozen_string_literal: true

module Cache

  class Store # :nodoc:

    include Enumerable

    # Public: Returns the hash of key-value pairs.
    attr_reader :data

    # Public: Initializes a new Cache object.
    #
    # data - A Hash of key-value pairs (optional).
    #        The values can be String or Cache::Data.
    #
    # Returns nothing.
    def initialize( data = {} )
      @data = {}
      load( data )
    end

    # Public: Retrieves the value for a given key.
    #
    # key - A String or Symbol representing the key.
    #
    # Returns the value set for the key; if nothing is
    #   set, returns nil.
    def get( key )
      checkKey!( key )
      expires!( key )
      @data[key.to_s]&.value
    end

    # Public: Sets a value for a given key either as
    # an argument or block.
    #
    # key   - A String or Symbol representing the key.
    # value - Any object that represents the value (optional).
    #         The value can be a Cache::Data.
    #         Not used if a block is given.
    # block - A block of code that returns the value to set (optional).
    #         Can be set a Cache::Data in the block.
    # expires_in - Time, in seconds, to expire the cache (optional).
    #              If not set, the cache never expires.
    #
    # Examples
    #
    #   cache.set("name", "Derrick")
    #   => "Derrick"
    #
    #   cache.set("name", "Derrick", expires_in: 60)
    #   => "Derrick"
    #
    #   cache.set("name") { "Joe" }
    #   => "Joe"
    #
    #   cache.set("name") { Cache::Data.new("Joe", 60) }
    #   => "Joe"
    #
    # Returns the value given.
    def set( key, value = nil, expiresIn: nil )

      checkKey!( key )

      data = block_given? ? yield : value

      @data[key.to_s] = if data.is_a?( Cache::Data )
                          data
                        else
                          Cache::Data.new(data, expires_in: expiresIn )
                        end
      get( key )
    end

    # Public: Determines whether a value has been set for
    # a given key.
    #
    # key - A String or Symbol representing the key.
    #
    # Returns a Boolean.
    def set?( key )
      checkKey!( key )
      expires!( key )
      @data.keys.include?( key.to_s )
    end

    # Public: Retrieves the value for a given key if it
    # has already been set; otherwise, sets the value
    # either as an argument or block.
    #
    # key   - A String or Symbol representing the key.
    # value - Any object that represents the value (optional).
    #         The value can be a Cache::Data.
    #         Not used if a block is given.
    # block - A block of code that returns the value to set (optional).
    #         Can be set a Cache::Data in the block.
    # expires_in - Time, in seconds, to expire the cache (optional).
    #              If not set, the cache never expires.
    #
    # Examples
    #
    #   cache.set("name", "Derrick")
    #   => "Derrick"
    #
    #   cache.get_or_set("name", "Joe")
    #   => "Derrick"
    #
    #   cache.get_or_set("occupation") { "Engineer" }
    #   => "Engineer"
    #
    #   cache.get_or_set("occupation") { "Pilot" }
    #   => "Engineer"
    #
    # Returns the value.
    def get_or_set( key, value = nil, expiresIn: nil )
      return get( key ) if set?( key )
      set(key, block_given? ? yield : value, expires_in: expiresIn )
    end

    # Public: Removes the key-value pair from the cache
    # for a given key.
    #
    # key - A String or Symbol representing the key.
    #
    # Returns the value.
    def unset( key )
      checkKey!( key )
      @data.delete( key.to_s )
    end

    # Public: Clears all key-value pairs.
    #
    # Returns nothing.
    def reset
      @data = {}
    end

    # Public: Iterates over all key-value pairs.
    #
    # block - A block of code that will be send the key
    #         and value of each pair.
    #
    # Yields the String key and value.
    def each
      @data.each { |k, v| yield( k, v ) }
    end

    # Public: Loads a hash of data into the cache.
    #
    # data - A Hash of data with either String or Symbol keys.
    #
    # Returns nothing.
    def load( data )
      data.each do |key, value|
        checkKey!( key )
        set( key, value )
      end
    end

    private

    # Internal: Raises an error if the key is not a String
    # or a Symbol.
    #
    # key - A key provided by the user.
    def checkKey!( key )
      return if key.is_a?( String ) || key.is_a?( Symbol )
      raise TypeError, 'key must be a String or Symbol'
    end

    # Internal: Verifies if data is expired and unset it
    def expires!( key )
      unset( key ) if @data[key.to_s]&.expired?
    end
  end
end
