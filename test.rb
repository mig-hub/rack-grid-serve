ENV['RACK_ENV'] = 'test'

require 'rack/grid_serve'
require 'rack/test'
require 'minitest/autorun'

Mongo::Logger.logger.level = Logger::ERROR

MONGO = Mongo::Client.new([ '127.0.0.1:27017' ], :database => 'rack-grid-serve-test')
DB = MONGO.database
DB.drop
DB.fs.open_upload_stream('tmnt.css', content_type: 'text/css') do |stream|
  stream.write '.cowabunga {}'
end
DB.fs.open_upload_stream('amazing tmnt.css', content_type: 'text/css') do |stream|
  stream.write '.cowabunga {}'
end
DB.fs.open_upload_stream('/slash-tmnt.css', content_type: 'text/css') do |stream|
  stream.write '.cowabunga {}'
end
FILE = DB.fs.find({filename: 'tmnt.css'}).first

module Helpers

  def inner_app
    lambda {|env| 
      [200, {'Content-Type'=>'text/plain'}, ["Inner"]] 
    }
  end

  def assert_file_found
    assert_equal 200, last_response.status
    assert_equal FILE['contentType'], last_response.headers['Content-Type']
    assert_equal 13, last_response.body.size
    assert_equal FILE['md5'], last_response.headers['ETag']
    assert_equal Time.at(FILE['uploadDate'].to_i).httpdate, last_response.headers['Last-Modified']
    assert_equal 'no-cache', last_response.headers['Cache-Control']
  end

end

class TestRackGridServe < MiniTest::Test

  include Rack::Test::Methods
  include Helpers

  def app
    Rack::Lint.new(Rack::GridServe.new(inner_app, db: DB).freeze).freeze
  end

  def test_finds_file_by_id
    get "/gridfs/#{FILE['_id']}"
    assert_file_found
  end

  def test_finds_file_by_name
    get '/gridfs/tmnt.css'
    assert_file_found
  end

  def test_finds_file_by_name_with_url_encoding
    get '/gridfs/amazing%20tmnt.css'
    assert_file_found
  end

  def test_finds_file_by_name_with_slash
    get '/gridfs/slash-tmnt.css'
    assert_file_found
  end

  def test_uses_conditional_get
    get '/gridfs/tmnt.css', {}, {'HTTP_IF_NONE_MATCH'=>FILE['md5']}
    assert_equal 304, last_response.status
  end

  def test_not_found_if_filename_has_no_match
    get '/gridfs/unexisting-id'
    assert_equal 404, last_response.status
  end

  def test_pass_if_prefix_only
    get '/gridfs'
    assert_equal 200, last_response.status
    assert_equal "Inner", last_response.body
  end

  def test_pass_if_root
    get '/'
    assert_equal 200, last_response.status
    assert_equal "Inner", last_response.body
  end

  def test_pass_if_prefix_not_match
    get '/wrong-prefix/1234'
    assert_equal 200, last_response.status
    assert_equal "Inner", last_response.body
  end

  def test_pass_if_prefix_not_at_the_begining
    get '/before/gridfs/1234'
    assert_equal 200, last_response.status
    assert_equal "Inner", last_response.body
  end

end

class TestRackGridServePrefix < MiniTest::Test

  include Rack::Test::Methods
  include Helpers

  def app
    Rack::Lint.new(
      Rack::GridServe.new(inner_app, db: DB, prefix: '/attachment/prefix/').freeze
    ).freeze
  end

  def test_finds_file_with_custom_prefix
    # prefix = "/attachment/prefix/"
    get '/attachment/prefix/tmnt.css'
    assert_file_found
  end

end

