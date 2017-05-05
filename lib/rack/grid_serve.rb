require 'mongo'
require 'rack/request'
begin
  require 'rack/conditional_get'
rescue LoadError => ex
  require 'rack/conditionalget'
end

class Rack::GridServe

  VERSION = '0.0.5'

  def initialize app, opts={}
    @app = app
    @db = opts[:db]
    @prefix = opts[:prefix] || 'gridfs'
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
        [404, {'Content-Type'=>'text/plain'}, 'Not Found']
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
    req.path_info =~ %r|/#@prefix/(.*)|
  end

  def id_or_filename req
    str = req.path_info.sub %r|/#@prefix/|, ''
    if BSON::ObjectId.legal? str
      BSON::ObjectId.from_string str
    else
      str
    end
  end

  def find_file req
    str = id_or_filename req
    @db.fs.find({
      '$or' => [
        {_id: str},
        {filename: str}
      ]
    }).first
  end

end

