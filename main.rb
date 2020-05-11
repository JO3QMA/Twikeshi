# frozen_string_literal: true

require 'zip'
require 'json'
require 'fileutils'
require 'twitter'
require 'pp'
require 'yaml'

# コマンドオプション
# -h ハッシュタグ  : ハッシュタグを含むツイートを除く
# -r リツイート    : 指定した数値以上のRTされたツイートを除く
# -f ふぁぼ       :　指定した数値以上のFavされたツイートを除く
# -t 時間         : 指定した時間以後のツイートを除く

config = YAML.load_file('./config.yml')
api = config['api']
option = config['option']
dest = 'tmp/'
def unzip(file = 'twitter.zip')
  Zip::File.open(file) do |zip|
    zip.each do |entry|
      p entry.name
      zip.extract(entry, dest + entry.name) { true }
    end
  end
end

def delete_tmp(dir = 'tmp/')
  FileUtils.rm_r(dir)
end

def load_json
  tweet_json = 'tmp/data/tweet.js'
  json_data = open(tweet_json) do |io|
    JSON.load(io)
  end
  json_data
end
test = load_json
id_array = []
test.each do |i|
  if option['RT'] < i['tweet']['retweet_count'].to_i
    
  elsif option['Fav'] < i['tweet']['favorite_count'].to_i

  else
    id_array.push i['tweet']['id']
  end
end

pp id_array
p id_array.count

client = Twitter::REST::Client.new do |config|
  config.consumer_key        = api['API_Key']
  config.consumer_secret     = api['API_Secret_Key']
  config.access_token        = api['Access_Token']
  config.access_token_secret = api['Access_Token_Secret']
end

def destroy(array)
  array.each do |tweet_id|
    client.destroy(tweet_id)

  end
end
destroy(id_array)