require 'timeout'
require 'mongo'

module Rack
  
  class GridFSConnectionError < StandardError ; end
  
  class GridFS

    attr_reader :hostname, :port, :database, :prefix, :db
    
    def initialize(app, options = {})
      options = {
        :hostname => 'localhost', 
        :prefix   => 'gridfs',
        :port     => Mongo::Connection::DEFAULT_PORT
      }.merge(options)

      @app        = app
      @hostname   = options[:hostname]
      @port       = options[:port]
      @database   = options[:database]
      @prefix     = options[:prefix]
      @db         = nil

      connect!
    end

    def call(env)
      request = Rack::Request.new(env)
      if request.path_info.index("/#{prefix}/") == 0
        if request.path_info =~ /^\/#{prefix}\/(.{24})(\/(.+))?$/
          gridfs_request($1)
        else
          unknown
        end
      else
        @app.call(env)
      end
    end

    def gridfs_request(id)
      file = Mongo::Grid.new(db).get(BSON::ObjectID.from_string(id))
      [200, {'Content-Type' => file.content_type}, [file.read]]
    rescue Mongo::GridError, BSON::InvalidObjectID
      unknown
    end
    
    def unknown
      [404, {'Content-Type' => 'text/plain'}, ['File not found.']]
    end
    
    private
    
    def connect!
      Timeout::timeout(5) do
        @db = Mongo::Connection.new(hostname).db(database)
      end
    rescue Exception => e
      raise Rack::GridFSConnectionError, "Unable to connect to the MongoDB server (#{e.to_s})"
    end
    
  end
    
end
