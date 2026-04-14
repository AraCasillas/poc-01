require_relative "app"

require 'rack'

use Rack::Static, urls: ["/css"], root: "../public"

run AvatarProxy