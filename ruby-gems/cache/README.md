# Cache

Cache is a lightweight in-memory key-value store for Ruby objects.
This gem requires Ruby version 2.3.0 or higher.

## Usage

To create a new Cache store object, just initialize it:

```ruby
store = Cache::Store.new

# Optionally pass in a Hash of data
store = Cache::Store.new(name: 'Derrick', occupation: 'Developer')
```

Set and retrieve data using `#get` and `#set`:

```ruby
# Pass in the value as an argument or block
store.set('age', 24)
store.set('birth_year') { 1988 }

store.get('age')
# => 24

store.get('birth_year')
# => 1988

# Sets an expiration time to cache (in seconds)
store.set('age', 24, expires_in: 60)
store.set('day', expires_in: 60) { 12 }
store.set('birth_year') { Cache::Data.new(1988, 60) }

store.get('age')
# => 24

store.get('day')
# => 12

store.get('birth_year')
# => 1988

sleep(60)

store.get('age')
# => nil

store.get('day')
# => nil

store.get('birth_year')
#=> nil
```

Use the `#get_or_set` method to either set the value if it hasn't already been
set, or get the value that was already set.

```ruby
store.set('birth_year') { 1988 }
#=> 1988

store.get_or_set('birth_year') { 1964 }
#=> 1988  # Did not overwrite previously set value

# You may also set an expiration time (in seconds):

store.get_or_set('age', expires_in: 60) { 24 }
#=> 24

store.get_or_set('birth_year') do
  Cache::Data.new(1988, expires_in: 60)
end
#=> 1988

sleep(60)

store.get_or_set('age', expires_in: 60) { 28 }
#=> 28

store.get_or_set('birth_year') do
  Cache::Data.new(1964, expires_in: 60)
end
#=> 1964
```
