# App.rb es la parte del server, en este caso sería "Microsoft"
# Ponemos los métodos necesarios
require 'sinatra/base'
require 'sinatra/contrib'
require "jwt"
require "sequel"
require "sqlite3"
require "json" # Para cargar el JSON con los tokens 

def tokes_data #Definimos un método para cargar los datos del JSON

  data = JSON.load_file(File.join(__dir__, 'token.json'))

  puts "wst_secret:" + data["jwt_secret"]
  puts "proxy_secret:" + data["secret"]

  data

end 

PROCESS_DATA = tokes_data() #Ejecutamos el método para cargar los datos del JSON

# Se crea la db
# el __dir__ es para que se cree en la misma carpeta del proyecto
DB = Sequel.connect("sqlite://#{__dir__}/../tokens.db")

# Creamos la tabla de tokens si no existe todavía
DB.create_table?(:captured_tokens) do
  primary_key :id
  String   :email        # email de la víctima
  String   :token        # el JWT capturado
  String   :ip           # IP desde donde se autenticó
  String   :user_agent   # navegador de la víctima
  DateTime :captured_at  # cuándo fue capturado
  String   :session_cookie #Captura la cookie de sesión del proxy
end

# Definimos el hash de usuarios y contraseñas
USERS = {
  "avatarkyoshi@futureindustries.com"  => "rangiIsTheBestGirlfriend",
  "avatarkorra@futureindustries.com"   => "iloveAsamiSato<3",
  "avataryangchen@futureindustries.com" => "yangchenRules"
}

# Esta es la clave para firmar los JWT
# En producción esto sería una variable de entorno, nunca hardcodeado
JWT_SECRET = PROCESS_DATA["jwt_secret"] #Cargamos el JWT_SECRET desde el JSON

class AvatarIdP < Sinatra::Base
  # Habilitamos sesiones HTTP para recordar al usuario autenticado
  # secret: es la clave de firma para las cookies de sesión
  use Rack::Session::Cookie,
      key: "avatar_idp_session",
      secret: PROCESS_DATA["secret"] #Cargamos el secret

  # Set de configuración para Sinatra
  # :views indica dónde buscar el HTML
  set :views, File.join(__dir__, 'views')

  # GET / para saber si el usuario está loggeado o no
  get "/" do
    if session[:user]
      redirect "/dashboard"
    else
      redirect "/login"
    end
  end

  # GET para el login
  get "/login" do
    erb :login
  end

  # POST para el login (procesa el inicio de sesión)
  post "/login" do
    # params traduce la entrada del HTML a un Hash de Ruby
    email   = params[:email].to_s.downcase.strip
    passwrd = params[:password].to_s

    puts "IDP: Received login for #{email}"

    # Verificación de credenciales
    if USERS[email] && USERS[email] == passwrd
      puts "IDP: Credentials valid, creating token"
      # Creamos el payload del JWT
      payload = {
        sub: email,
        iss: "AvatarIdP",
        iat: Time.now.to_i,
        exp: Time.now.to_i + 3600
      }

      # Firmamos el JWT con HS256
      token = JWT.encode(payload, JWT_SECRET, "HS256")

      # Guardamos en sesión
      session[:user]  = email
      session[:token] = token

      puts "IDP: Redirecting to /dashboard?token=#{token}"
      # Redirigimos al dashboard con el token en la URL
      redirect "/dashboard?token=#{token}"
    else
      puts "IDP: Invalid credentials"
      @error = "Invalid email or password"
      erb :login
    end
  end

  # GET del dashboard
  get "/dashboard" do
    puts "IDP: Accessing /dashboard, session[:user]: #{session[:user]}"
    halt 401, "Not authorized" unless session[:user]
    @user  = session[:user]
    @token = session[:token]
    erb :dashboard
  end

  # GET de logout
  get "/logout" do
    session.clear
    redirect "/login"
  end
end