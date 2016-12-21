
# ---------------------------------------------------------------------------------------
#
# monkey patches

module DataMapper
  module Model
    def update_or_create( conditions = {}, attributes = {}, merger = true )
      ( first( conditions ) && first( conditions ).update( attributes ) ) || create( merger ? ( conditions.merge( attributes ) ) : attributes )
    end
  end # Module Model
end # Module DataMapper

module DataMapper
  class Property
    class MD5 < String
      key    true
      length 32

      accept_options :fields

      default lambda { |resource, property| Digest::MD5.hexdigest( property.options[ :fields ].join ) }
    end
  end
end

# ---------------------------------------------------------------------------------------

class Dns
  include DataMapper::Resource

  property :id          , Serial
  property :ip          , IPAddress, :required => true, :key => true, :index => true
  property :shortname   , String   , :required => true, :key => true, :index => true, :length => 60
  property :longname    , String   , :required => true,               :length => 250
  property :created     , DateTime , :default => lambda{ |p,s| DateTime.now }
  property :checksum    , MD5      , :fields => [ :ip, :shortname ]

  has n, :discovery
end

class Discovery
  include DataMapper::Resource

  property :id          , Serial
  property :created     , DateTime , :default => lambda{ |p,s| DateTime.now }
  property :service     , String   , :required => true, :length => 64, :index => true
  property :data        , Json     , :required => true
  property :status      , Boolean  , :default => false

  belongs_to :dns
  has n, :result
end

class Result
  include DataMapper::Resource

  property :id          , Serial
  property :created     , DateTime , :default => lambda{ |p,s| DateTime.now }
  property :service     , String   , :required => true, :length => 60
  property :data        , Json     , :required => true

  belongs_to :discovery
end

# ---------------------------------------------------------------------------------------
