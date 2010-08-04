require 'test_helper'

class Rack::GridFSTest < Test::Unit::TestCase
  include Rack::Test::Methods
  
  def stub_mongodb_connection
    Rack::GridFS.any_instance.stubs(:connect!).returns(true)
  end
  
  def test_database_options
    { :hostname => 'localhost', :port => 27017, :database => 'test', :prefix => 'gridfs' }
  end
  
  def db
    @db ||= Mongo::Connection.new(test_database_options[:hostname], test_database_options[:port]).db(test_database_options[:database])
  end
  
  def app 
    gridfs_opts = test_database_options
    Rack::Builder.new do
      use Rack::GridFS, gridfs_opts
      run lambda { |env| [200, {'Content-Type' => 'text/plain'}, ["Hello, World!"]] }
    end
  end

  def load_artifact(filename, content_type)
    contents = File.read(File.join(File.dirname(__FILE__), 'artifacts', filename))
    Mongo::Grid.new(db).put(contents, :filename => filename, :content_type => content_type)
  end

  context "Rack::GridFS" do

    context "on initialization" do

      setup do
        stub_mongodb_connection
        @options = { :hostname => 'myhostname.mydomain', :port => 8765, :database => 'mydatabase', :prefix => 'myprefix' }
      end

      should "have a hostname option" do
        mware = Rack::GridFS.new(nil, @options)
        assert_equal @options[:hostname], mware.hostname
      end

      should "have a default hostname" do
        mware = Rack::GridFS.new(nil, @options.except(:hostname))
        assert_equal 'localhost', mware.hostname
      end

      should "have a port option" do
        mware = Rack::GridFS.new(nil, @options)
        assert_equal @options[:port], mware.port
      end

      should "have a default port" do
        mware = Rack::GridFS.new(nil, @options.except(:port))
        assert_equal Mongo::Connection::DEFAULT_PORT, mware.port
      end

      should "have a database option" do
        mware = Rack::GridFS.new(nil, @options)
        assert_equal @options[:database], mware.database
      end

      should "not have a default database" do
        mware = Rack::GridFS.new(nil, @options.except(:database))
        assert_nil mware.database
      end

      should "have a prefix option" do
        mware = Rack::GridFS.new(nil, @options)
        assert_equal mware.prefix, @options[:prefix]
      end
      
      should "have a default prefix" do
        mware = Rack::GridFS.new(nil, @options.except(:prefix))
        assert_equal mware.prefix, 'gridfs'
      end

      should "connect to the MongoDB server" do
        Rack::GridFS.any_instance.expects(:connect!).returns(true).once
        Rack::GridFS.new(nil, @options)
      end

    end

    should "delegate requests with a non-matching prefix" do
      %w( / /posts /posts/1 /posts/1/comments ).each do |path|
        get path
        assert last_response.ok?
        assert 'Hello, World!', last_response.body
      end
    end

    context "with files in GridFS" do
      setup do
        @text_id = load_artifact('test.txt', 'text/plain')
        @html_id = load_artifact('test.html', 'text/html')
      end

      teardown do
        db.collection('fs.files').remove
      end

      should "return TXT files stored in GridFS" do
        get "/gridfs/#{@text_id}"
        assert_equal "Lorem ipsum dolor sit amet.", last_response.body
      end

      should "return the proper content type for TXT files" do
        get "/gridfs/#{@text_id}"
        assert_equal 'text/plain', last_response.content_type
      end

      should "return HTML files stored in GridFS" do
        get "/gridfs/#{@html_id}"
        assert_match /html.*?body.*Test/m, last_response.body
      end
      
      should "return the proper content type for HTML files" do
        get "/gridfs/#{@html_id}"
        assert_equal 'text/html', last_response.content_type
      end
      
      should "return a not found for a unknown path" do
        get '/gridfs/unknown'
        assert last_response.not_found?
      end
      
      should "work for small images" do
        image_id = load_artifact('3wolfmoon.jpg', 'image/jpeg')
        get "/gridfs/#{image_id}"
        assert last_response.ok?
        assert_equal 'image/jpeg', last_response.content_type
      end
      
      should "work when filename information is included after the id" do
        image_id = load_artifact('3wolfmoon.jpg', 'image/jpeg')
        get "/gridfs/#{image_id}/3wolfmoon.jpg"
        assert last_response.ok?
        assert_equal 'image/jpeg', last_response.content_type
      end
    end

  end

end

