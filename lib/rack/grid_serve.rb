require 'mongo'
require 'rack/request'
require 'rack/utils'
begin
  require 'rack/conditional_get'
rescue LoadError
  require 'rack/conditionalget'
end

class Rack::GridServe

  VERSION = '0.0.9'.freeze

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

  PATH_INFO = 'PATH_INFO'.freeze
  CONTENT_TYPE = 'Content-Type'.freeze
  CONTENT_LENGTH = 'Content-Length'.freeze
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

  def call env
    path_info = env[PATH_INFO].to_s
    if under_prefix? path_info
      file = find_file path_info
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
        if can_use_cached?(env, file[MD5_KEY])
          headers.delete(CONTENT_TYPE)
          headers.delete(CONTENT_LENGTH)
          [304, headers, []]
        else
          [200, headers, @db.fs.open_download_stream(file[ID_KEY])]
        end
      end
    else
      @app.call env
    end
  end

  private

  def under_prefix? path_info
    path_info.start_with?(@prefix) and path_info.size > @prefix.size 
  end

  def id_or_filename path_info
    str = path_info.sub @prefix, EMPTY_STRING
    if BSON::ObjectId.legal? str
      BSON::ObjectId.from_string str
    else
      Rack::Utils.unescape str
    end
  end

  OR = '$or'.freeze

  def find_file path_info
    str = id_or_filename path_info
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

  READ_METHODS = ['GET'.freeze, 'HEAD'.freeze].freeze
  REQUEST_METHOD = 'REQUEST_METHOD'.freeze
  HTTP_IF_NONE_MATCH = 'HTTP_IF_NONE_MATCH'.freeze

  def can_use_cached? env, md5
    READ_METHODS.include?(env[REQUEST_METHOD]) and 
      env[HTTP_IF_NONE_MATCH] and 
      env[HTTP_IF_NONE_MATCH] == md5
  end

end

