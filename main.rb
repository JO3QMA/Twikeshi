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
def unzip(file = 'twitter.zip')
  
dest = 'tmp/'
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

def reformat_json
  file = File.open('tmp/data/tweet.js', 'r')
  buffer = file.read
  buffer.gsub!('window.YTD.tweet.part0 = [ {', '[ {')
  file = File.open('tmp/data/tweet.js', 'w')
  file.write(buffer)
  file.close
end

def load_json
  tweet_json = 'tmp/data/tweet.js'
  json_data = open(tweet_json) do |io|
    JSON.load(io)
  end
  json_data
end
unzip
reformat_json
test = load_json
p load_json.count
id_array = []
deny_array = []
test.each do |i|
  retweet = i['tweet']['retweet_count'].to_i
  favorite = i['tweet']['favorite_count'].to_i
  hashtags = i['tweet']['entities']['hashtags']
  created_at = Date.parse(i['tweet']['created_at'])
  if !option['Until'].empty?
    until_time = Date.parse(option['Until'])
  end
  if !option['Since'].empty?
    since_time = Date.parse(option['Since'])
  end
  if !option['RT'] == -1 && retweet > option['RT']
    deny_array.push i['tweet']['id']
  elsif !option['Fav'] == -1 && favorite > option['Fav']
    deny_array.push i['tweet']['id']
  elsif !option['Hashtag'].empty? && hashtags.empty?
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
  elsif !option['Until'].empty? && created_at < until_time
    deny_array.push i['tweet']['id']
  elsif !option['Since'].empty? && created_at > since_time
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
  count = 0
  array.each do |tweet_id|
    count += 1
    client.destroy(tweet_id)
    progress(count)
  end
end

def progress(count)
  count -= 1
  percent = count / load_json.count.to_f * 100
  scale = 2
  bar = percent / scale
  hide_bar = 100 / scale - bar.floor
  print "\r#{count}件目 [#{'=' * bar}#{' ' * hide_bar}] #{percent.floor(1)}%完了"
  puts '' if count == load_json.count
end
 destroy(id_array)
 delete_tmp