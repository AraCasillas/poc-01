# Cargar gemas necesarias
require 'faraday'
require 'dotenv/load'
require 'uri'

# Obtener variables del proxy desde el archivo .env
# Formato esperado en .env:
# PROXY_HOST=localhost
# PROXY_PORT=4444
# PROXY_USER=usuario
# PROXY_PASS=contraseña

proxy_host = ENV['PROXY_HOST'] || 'localhost'
proxy_port = ENV['PROXY_PORT'] || '4444'
proxy_user = ENV['PROXY_USER'] || ''
proxy_pass = ENV['PROXY_PASS'] || ''

# Construir la URL del proxy con credenciales de autenticación
proxy_url = if proxy_user.empty?
  # Si no hay usuario, usar URL simple
  "http://#{proxy_host}:#{proxy_port}"
else
  # Si hay usuario, incluir las credenciales
  "http://#{proxy_user}:#{proxy_pass}@#{proxy_host}:#{proxy_port}"
end

# Crear conexión HTTP con configuración del proxy
conn = Faraday.new(proxy: proxy_url) do |f|
  # Adaptador por defecto de Faraday (usa Net::HTTP)
  f.adapter Faraday.default_adapter
  # Registrar las peticiones HTTP para debugging
  f.response :logger
end

# Realizar una petición GET a través del proxy
response = conn.get('http://localhost')

# Imprimir el cuerpo de la respuesta
puts response.body
