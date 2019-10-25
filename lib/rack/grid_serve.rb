require 'mongo'
require 'rack/request'
require 'rack/utils'
begin
  require 'rack/conditional_get'
rescue LoadError
  require 'rack/conditionalget'
end

class Rack::GridServe

  VERSION = '0.0.8'.freeze

  DEFAULT_PREFIX = 'gridfs'.freeze
  DEFAULT_CACHE_CONTROL = 'no-cache'.freeze
  EDGE_SLASHES_RE = /\A\/|\/\z/.freeze
  EMPTY_STRING = ''.freeze

  def initialize app, opts={}
    @app = app
    @db = opts[:db]
    @prefix = (opts[:prefix] || DEFAULT_PREFIX).gsub(EDGE_SLASHES_RE, EMPTY_STRING)
    @prefix = "/#{@prefix}/".freeze
    @cache_control = opts[:cache_control] || DEFAULT_CACHE_CONTROL
  end

  def call env
    dup._call env
  end

  CONTENT_TYPE = 'Content-Type'.freeze
  LAST_MODIFIED = 'Last-Modified'.freeze
  CACHE_CONTROL = 'Cache-Control'.freeze
  ETAG = 'ETag'.freeze
  TEXT_PLAIN = 'text/plain'.freeze
  NOT_FOUND = 'Not Found'.freeze
  NOT_FOUND_RESPONSE = [
    404, 
    {
      CONTENT_TYPE => TEXT_PLAIN
    }.freeze, 
    [NOT_FOUND].freeze
  ].freeze
  UPLOAD_DATE_KEY = 'uploadDate'.freeze
  CONTENT_TYPE_KEY = 'contentType'.freeze
  ID_KEY = '_id'.freeze
  MD5_KEY = 'md5'.freeze

  def _call env
    req = Rack::Request.new env
    if under_prefix? req
      file = find_file req
      if file.nil?
        NOT_FOUND_RESPONSE
      else
        last_modified = Time.at file[UPLOAD_DATE_KEY].to_i
        headers = {
          CONTENT_TYPE => file[CONTENT_TYPE_KEY],
          ETAG => file[MD5_KEY],
          LAST_MODIFIED => last_modified.httpdate,
          CACHE_CONTROL => @cache_control
        }
        Rack::ConditionalGet.new(lambda {|cg_env|
          content = String.new
          @db.fs.open_download_stream(file[ID_KEY]) do |stream|
            content = stream.read
          end
          [200, headers, [content]]
        }).call(env)
      end
    else
      @app.call env
    end
  end

  private

  def under_prefix? req
    req.path_info.start_with?(@prefix) and req.path_info.size > @prefix.size 
  end

  def id_or_filename req
    str = req.path_info.sub @prefix, EMPTY_STRING
    if BSON::ObjectId.legal? str
      BSON::ObjectId.from_string str
    else
      Rack::Utils.unescape str
    end
  end

  OR = '$or'.freeze

  def find_file req
    str = id_or_filename req
    if str.is_a? BSON::ObjectId
      @db.fs.find({_id: str}).first
    else
      @db.fs.find({
        OR => [
          {filename: str},
          {filename: "/#{str}"}
        ]
      }).first
    end
  end

end

