# config.ru
require_relative "idp/app"

require 'rack'

use Rack::Static, urls: ["/css"], root: "public"

run AvatarIdP