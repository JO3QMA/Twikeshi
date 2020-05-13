# frozen_string_literal: true

require 'oauth'
require 'yaml'

config = YAML.load_file('./config.yml')

ck = config['api']['API_Key']
cs = config['api']['API_Secret_Key']

consumer = OAuth::Consumer.new ck, cs, site: 'https://api.twitter.com'

request_token = consumer.get_request_token

puts "認証URL: #{request_token.authorize_url}"
STDERR.print 'PINコードを入力してください。: '

access_token = request_token.get_access_token oauth_verifier: gets.chomp
puts "Access Token : #{access_token.token}"
puts "Access Secret: #{access_token.secret}"
