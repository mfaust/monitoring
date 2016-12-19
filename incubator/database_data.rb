


      class Dns
        include DataMapper::Resource

        property :id          , Serial
        property :ip          , IPAddress, :required => true, :key => true
        property :shortname   , String   , :required => true, :key => true, :length => 60
        property :longname    , String   , :required => true,               :length => 250
        property :checksum    , String   , :length => 64    , :key => true, :default => lambda { |r, p| Digest::SHA256.hexdigest( r.shortname ) }

        has 1, :discovery
      end

      class Discovery
        include DataMapper::Resource

        property :id          , Serial
        property :created     , DateTime , :default => lambda{ |p,s| DateTime.now }
#         property :shortname   , String   , :required => true, :length => 60
#         property :md5sum      , String   , :required => true, :length => 64, :key => true
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
#         property :md5sum      , String   , :required => true, :length => 64, :key => true
        property :data        , Json     , :required => true

        belongs_to :discovery
      end


