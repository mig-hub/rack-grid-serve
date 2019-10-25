require 'mongo'
require 'rack/request'
require 'rack/utils'
begin
  require 'rack/conditional_get'
rescue LoadError
  require 'rack/conditionalget'
end

class Rack::GridServe

  VERSION = '0.0.8'

  def initialize app, opts={}
    @app = app
    @db = opts[:db]
    @prefix = (opts[:prefix] || 'gridfs').gsub(/\A\/|\/\z/, '')
    @prefix = "/#{@prefix}/".freeze
    @cache_control = opts[:cache_control] || 'no-cache'
  end

  def call env
    dup._call env
  end

  def _call env
    req = Rack::Request.new env
    if under_prefix? req
      file = find_file req
      if file.nil?
        [404, {'Content-Type'=>'text/plain'}, ['Not Found']]
      else
        last_modified = Time.at file['uploadDate'].to_i
        headers = {
          'Content-Type' => file['contentType'],
          'ETag' => file['md5'],
          'Last-Modified' => last_modified.httpdate,
          'Cache-Control' => @cache_control
        }
        Rack::ConditionalGet.new(lambda {|cg_env|
          content = String.new
          @db.fs.open_download_stream(file['_id']) do |stream|
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
    str = req.path_info.sub @prefix, ''
    if BSON::ObjectId.legal? str
      BSON::ObjectId.from_string str
    else
      Rack::Utils.unescape str
    end
  end

  def find_file req
    str = id_or_filename req
    if str.is_a? BSON::ObjectId
      @db.fs.find({_id: str}).first
    else
      @db.fs.find({
        '$or' => [
          {filename: str},
          {filename: "/#{str}"}
        ]
      }).first
    end
  end

end

