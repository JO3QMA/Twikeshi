# frozen_string_literal: true

require 'zip'
require 'json'
require 'fileutils'
require 'twitter'
require 'pp'
require 'yaml'
require 'date'

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
p load_json.count
id_array = []
deny_array = []
test.each do |i|
  retweet = i['tweet']['retweet_count'].to_i
  favorite = i['tweet']['favorite_count'].to_i
  hashtags = i['tweet']['entities']['hashtags']
  created_at = Date.strptime(i['tweet']['created_at'] ,"%a %b %d %T %z %Y")
  if retweet > option['RT']
    deny_array.push i['tweet']['id']
  elsif favorite > option['Fav']
    deny_array.push i['tweet']['id']
  elsif hashtags.empty?
    found = false
    hashtags.each do |hashtag_hash|
      if hashtag_hash['text'] == option['Hashtag']
        found = true
        break
      else
        found = false
      end
    end
    if found == true
      deny_array.push i['tweet']['id']
    else
      id_array.push i['tweet']['id']
    end
  elsif created_at < option['until']
    deny_array.push i['tweet']['id']
  elsif created_at > option['since']
    deny_array.push i['tweet']['id']
  else
    id_array.push i['tweet']['id']
  end
end

p id_array.count
pp deny_array

p deny_array.count
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
#destroy(id_array)
