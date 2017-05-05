ENV['RACK_ENV'] = 'test'

require 'rack/grid_serve'
require 'rack/test'
require 'minitest/autorun'

class TestRackGridServe < MiniTest::Test

  MONGO = Mongo::Client.new([ '127.0.0.1:27017' ], :database => 'rack-grid-serve-test')
  DB = MONGO.database
  DB.drop
  FILE = Mongo::Grid::File.new('.cowabunga {}', :filename => 'tmnt.css', content_type: 'text/css')
  FILE_ID = DB.fs.insert_one(FILE)

  include Rack::Test::Methods

  def app
    Rack::Lint.new(Rack::GridServe.new(inner_app, db: DB))
  end

  def inner_app
    lambda {|env| 
      [200, {'Content-Type'=>'text/plain'}, ["Inner"]] 
    }
  end

  def assert_file_found
    assert_equal 200, last_response.status
    assert_equal 13, last_response.body.size
    assert_equal FILE.info.content_type, last_response.headers['Content-Type']
    assert_equal FILE.info.md5, last_response.headers['ETag']
    assert_equal Time.at(FILE.info.upload_date.to_i).httpdate, last_response.headers['Last-Modified']
    assert_equal 'no-cache', last_response.headers['Cache-Control']
  end

  def test_finds_file_by_id
    get "/gridfs/#{FILE_ID}"
    assert_file_found
  end

  def test_finds_file_by_name
    get '/gridfs/tmnt.css'
    assert_file_found
  end

  def test_uses_conditional_get
    get '/gridfs/tmnt.css', {}, {'HTTP_IF_NONE_MATCH'=>FILE.info.md5}
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

end

