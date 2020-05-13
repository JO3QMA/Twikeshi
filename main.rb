# frozen_string_literal: true

# TODO
#  削除処理実際に動かないと思うのでそれの対処
#  exe化

require 'zip'
require 'json'
require 'fileutils'
require 'twitter'
require 'pp'
require 'yaml'
require 'date'

class TweetDeleter
  def initialize
    puts '初期処理をしています。'
    @tmp_dir = 'tmp/'
    yaml_file = YAML.load_file('./config.yml')
    api = yaml_file['api']
    @option = yaml_file['option']
    @until_time = Date.parse(@option['Until']) unless @option['Until'].empty?
    @since_time = Date.parse(@option['Since']) unless @option['Since'].empty?
    @client = Twitter::REST::Client.new do |config|
      config.consumer_key        = api['API_Key']
      config.consumer_secret     = api['API_Secret_Key']
      config.access_token        = api['Access_Token']
      config.access_token_secret = api['Access_Token_Secret']
    end
    @allow_array = []
    @deny_array = []
    puts '初期処理を完了しました。'
  end

  def unzip(file)
    puts "#{file}を展開しています。"
    FileUtils.mkdir_p('./tmp/data')
    Zip::File.open(file) do |zip|
      zip.each do |entry|
        if entry.name == 'data/tweet.js'
          zip.extract(entry, @tmp_dir + entry.name) { true }
        end
      end
    end
    puts '展開を完了しました。'
  end

  def make_json
    puts 'tweet.jsからJSONを生成しています。'
    file = File.open(@tmp_dir + 'data/tweet.js', 'r')
    buffer = file.read
    buffer.gsub!('window.YTD.tweet.part0 = [ {', '[ {')
    file = File.open(@tmp_dir + 'data/tweet.js', 'w')
    file.write(buffer)
    file.close
    puts 'JSONの生成が完了しました。'
  end

  def load_json
    puts 'JSONのロードを開始しています。'
    file = open(@tmp_dir + 'data/tweet.js') do |io|
      JSON.load(io)
    end
    puts 'JSONのロードを完了しました。'
    puts "#{file.count}件のツイートを読み込み終わりました。"
    file
  end

  def seach_tweet(tweets)
    puts 'ツイートの除外検索を開始しています。'
    tweets.each do |tweet|
      retweet = tweet['tweet']['retweet_count'].to_i
      favorite = tweet['tweet']['favorite_count'].to_i
      hashtags = tweet['tweet']['entities']['hashtags']
      created_at = Date.parse(tweet['tweet']['created_at'])
      if !@option['RT'] == -1 && retweet > @option['RT']
        deny_pusher(tweet)
      elsif !@option['Fav'] == -1 && favorite > @option['Fav']
        deny_pusher(tweet)
      elsif !@option['Until'].empty? && created_at < @until_time
        deny_pusher(tweet)
      elsif !@option['Since'].empty? && created_at > @since_time
        deny_pusher(tweet)
      elsif !@option['Hashtag'].empty? && !hashtags.empty?
        hit = false
        hashtags.each do |hashtag|
          if hashtag['text'] == @option['Hashtag']
            hit = true
          end
        end
        if hit == true
          deny_pusher(tweet)
        else
          allow_pusher(tweet) # ここがおかしい。ハッシュタグ含んでいて条件に引っかからなかったら問答無用で消されるのはおかしい
        end
      else
        allow_pusher(tweet)
      end
    end
    puts 'ツイートの検索を終了しました。'
    puts "検索件数: #{tweets.count}件"
    puts "除外件数: #{@deny_array.count}件"
    puts "削除件数: #{@allow_array.count}件"
  end

  def allow_pusher(tweet)
    @allow_array.push tweet['tweet']['id']
  end

  def deny_pusher(tweet)
    @deny_array.push tweet['tweet']['id']
  end

  def delete_tweets
    count = 0
    @allow_array.each do |tweet|
      count += 1
      #@client.destroy(tweet)
      progress(count)
    end
  end

  def progress(count)
    percent = count / @allow_array.count.to_f * 100
    scale = 2
    bar = percent / scale
    hide_bar = 100 /scale - bar.floor
    print "\r#{count}件目 [#{'=' * bar}#{' ' * hide_bar}] #{percent.floor(1)}%完了"
    puts '' if count == @allow_array.count
  end

  def delete_tmp_dir
    FileUtils.rm_r(@tmp_dir)
  end

  def confirmation
    STDERR.print '削除処理を実行しますか？(Y/N): '
    responce = STDIN.gets.chomp
    if responce != 'Y'
      exit
    end
  end

  def main
    if ARGV[0] == nil
      zip_name = 'twitter.zip'
    else
      zip_name = ARGV[0]
    end
    unzip(zip_name)
    make_json
    seach_tweet(load_json)
    confirmation
    delete_tweets
    delete_tmp_dir
    pp @allow_array
  end
end
test = TweetDeleter.new
test.main