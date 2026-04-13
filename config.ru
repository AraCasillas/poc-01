# config.ru
require_relative "idp/app"

# Servir los archivos estáticos de /public (CSS, imágenes)
use Rack::Static,
    urls: ["/css"],
    root: "public"

run AvatarIdP