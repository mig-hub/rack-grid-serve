Rack Grid Serve
===============

The purpose of `Rack::GridServe` is to provide an alternative to
[Rack::Gridfs]() which works with the `Mongo` ruby driver version 2.0 
and above. This driver has a different API and while the `Rack::Gridfs` 
team is working on it, it is not yet ready.

While `Rack::GridServe` can be used the same way, it is by no mean
as complete and well crafted as `Rack::Gridfs`. So I recommend that
you switch back when their next version is ready.

Until then, the function is the same, you can mount the middleware
in order to serve images which are hosted in the `GridFS` part
of a `Mongo` database.

How it works
------------

Here is how you mount it in your `config.ru`:

```ruby
require 'rack/grid_serve'
use Rack::GridServe, {
  db: $db,
  prefix: 'gridfs', # Path prefix, default is "gridfs"
  cache_control: 'no-cache' # Default is "no-cache"
}
```

These are the only options so far.

`Rack::GridServe` sets the `ETag` and `Last-Modified` response
headers and uses `Rack::ConditionalGet` to let the browser use
cached version of the files when possible.

Testing
-------

Run tests this way:

```
bundle exec ruby -I lib test.rb
```

