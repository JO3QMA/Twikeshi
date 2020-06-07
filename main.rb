# frozen_string_literal: true

require 'zip'
require 'json'
require 'fileutils'
require 'twitter'
require 'yaml'
require 'date'

# 全部の処理
class TweetDeleter
  def initialize
    puts '初期処理をしています。'
    @tmp_dir = 'tmp/'
    yaml_file = YAML.load_file('./config.yml')
    api = yaml_file['api']
    @option = yaml_file['option']
    @until_time = Date.parse(@option['Until']) unless @option['Until'].empty? # 先に日付周りは整形しておく
    @since_time = Date.parse(@option['Since']) unless @option['Since'].empty? # 先に日付周りは整形しておく
    @client = Twitter::REST::Client.new do |config|
      config.consumer_key        = api['API_Key']
      config.consumer_secret     = api['API_Secret_Key']
      config.access_token        = api['Access_Token']
      config.access_token_secret = api['Access_Token_Secret']
    end
    @allow_array = [] # 削除するツイートIDが入った配列
    @deny_array = []  # 削除しないツイートIDが入った配列 (デバッグ用なので必要ない)
    puts '初期処理を完了しました。'
  end

  def unzip(file)
    puts "#{file}を展開しています。"
    FileUtils.mkdir_p('./tmp/data') # 先にフォルダーを作っておかないと中身を展開できなくて死ぬ
    Zip::File.open(file) do |zip|
      zip.each do |entry|
        # 全部展開するよりも、必要なものを抽出するほうが実行時間が短い
        zip.extract(entry, @tmp_dir + entry.name) { true } if entry.name == 'data/tweet.js'
      end
    end
    puts '展開を完了しました。'
  end

  def make_json
    puts 'tweet.jsからJSONを生成しています。'
    file = File.open(@tmp_dir + 'data/tweet.js', 'r')
    buffer = file.read
    # JSONにするときに必要ではないゴミを消す。
    buffer.gsub!('window.YTD.tweet.part0 = [ {', '[ {')
    file = File.open(@tmp_dir + 'data/tweet.json', 'w')
    file.write(buffer)
    file.close
    puts 'JSONの生成が完了しました。'
  end

  def load_json
    puts 'JSONのロードを開始しています。'
    file = open(@tmp_dir + 'data/tweet.json') do |io|
      JSON.load(io)
    end
    puts 'JSONのロードを完了しました。'
    puts "#{file.count}件のツイートを読み込みました。"
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
          hit = true if hashtag['text'] == @option['Hashtag']
        end
        if hit == true
          deny_pusher(tweet)
        else
          allow_pusher(tweet) # ハッシュタグ含んでいて条件に引っかからなかったら問答無用で消されるのはおかしい
        end
      else
        allow_pusher(tweet)
      end
    end
    puts 'ツイートの検索を終了しました。'
    puts "除外: #{@deny_array.count}件"
    puts "削除: #{@allow_array.count}件"
  end

  def allow_pusher(tweet)
    @allow_array.push tweet['tweet']['id']
  end

  def deny_pusher(tweet)
    @deny_array.push tweet['tweet']['id']
  end

  def delete_tweets
    puts '削除処理を開始しました。'
    # 削除するときに配列で渡したほうが絶対に効率がいいけど、
    # 削除できないツイート(すでに存在しなかったり)があるとエラー吐いて死ぬため、一つずつ叩くようにする。
    count = 0
    error_array = []
    @allow_array.each do |tweet|
      count += 1
      begin
        @client.destroy_status(tweet)
      rescue StandardError
        # とりあえずエラーツイートをカウントするために配列に入れる。
        error_array.push tweet
      end
      progress(count)
    end
    puts '削除処理が完了しました。'
    puts "エラー: #{error_array.count}件"
  end

  def progress(count)
    percent = count / @allow_array.count.to_f * 100
    scale = 2
    bar = percent / scale
    hide_bar = 100 / scale - bar.floor
    print "\r#{count}件目 [#{'=' * bar}#{' ' * hide_bar}] #{percent.floor(1)}%完了"
    puts '' if count == @allow_array.count
  end

  def delete_tmp_dir
    puts "#{@tmp_dir}を削除しています。"
    FileUtils.rm_r(@tmp_dir)
    puts '削除を完了しました。'
  end

  def confirmation
    STDERR.print '削除処理を実行する場合、「DELETE」と入力してください。: '
    responce = STDIN.gets.chomp
    exit if responce != 'DELETE'
  end

  def jobs
    # 正直unzipの中で処理させたほうがいい気がするけど、めんどくさいのでここで。
    zip_name = if ARGV[0].nil?
                 'twitter.zip'
               else
                 ARGV[0]
               end
    unzip(zip_name)
    make_json
    seach_tweet(load_json)
    confirmation
    delete_tweets
    delete_tmp_dir
  end
end
main = TweetDeleter.new
main.jobs
