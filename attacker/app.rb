require 'faraday'
require 'dotenv/load'
require 'uri'

proxy_url = URI::HTTP.build(
    host: ENV['PROXY_HOST'],
    port: ENV['PROXY_PORT'].to_i
    userinfo: "#{ENV['PROXY_USER']}:#{ENV['PROXY_PASS']}"
).to_s


conn = Faraday.new(proxy: proxy_url) do |f|
    f.adapter Faraday.default_adapter
end 

response = conn.get('http://localhost:4567/dashboard?token=eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJ1c2VyQGV4YW1wbGUuY29tIiwiaXNzIjoiQXZhdGFySURQIiwiaWF0IjoxNjg4ODk5MDg3LCJleHAiOjE2ODg4OTkyODd9.7n8sHj8l6mLh5a3e7v9z0w1x2y3z4a5b6c7d8e9f0g')
puts "Your IP through the proxy is: #{response.body}"


