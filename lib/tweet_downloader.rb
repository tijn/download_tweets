#!/usr/bin/env ruby
require 'rubygems'
require 'net/http'
require 'json'


class TweetDownloader
  attr_reader :user, :tweet_dir

  # twitter wants 150 requests per hour at max, we're being nice, so we sleep about 30 seconds before doing a new request
  SLEEPY_TIME = 1 # 3600 / 120
  MAX_REQUESTS = 150

  def initialize(username, directory)
    raise "username is incorrect: #{username.inspect}" if username.nil? or username.empty?
    @user = username
    @tweet_dir = directory
    @requests_remaining = MAX_REQUESTS
  end

  # I just realized that I don't know for sure if status ids are increasing...
  def since_id
    Dir.glob("#{tweet_dir}/*.json").map { |f| File.basename(f, ".json").to_i rescue 1 }.max
  end

  def go(options = {})
    download_tweets(options)
    download_in_reply_to(options)
  end

  def download_tweets(options = {})
    options[:since_id] ||= since_id
    options[:count] ||= 100
    tweets = fetch_page(options)
    STDERR.puts "#{tweets.size} tweets"
    save_tweets(tweets)
    unless tweets.empty?
      # twitter starts counting pages at 1 (not at zero)
      download_tweets(options.merge(:page => (options[:page] || 1) + 1))
    end
  end

  def filename(tweet)
    filename_for_id(tweet["id"])
  end

  def filename_for_id(id)
    "#{tweet_dir}/#{id}.json"
  end

  def save_tweets(tweets)
    tweets.each do |tweet|
      next if File.exists?(filename(tweet))
      File.open(filename(tweet), 'w') { |f| f.puts tweet.to_json }
      STDERR.puts "#{tweet["created_at"]}\t#{tweet["text"]}"
    end
  rescue
    STDERR.puts tweets.inspect
    raise
  end

  def page_path(options = {})
    path = "/statuses/user_timeline/#{@user}.json"
    unless options.empty?
      opts = options.map do |k,v|
        next if v.nil?
        "#{k}=#{v}"
      end
      "#{path}?#{opts.join("&")}"
    end
  end

  def show_path(options = {})
    path = "/1/statuses/show.json"
    unless options.empty?
      opts = options.map do |k,v|
        next if v.nil?
        "#{k}=#{v}"
      end
      "#{path}?#{opts.join("&")}"
    end
  end

  def fetch_page(options = {})
    return if @requests_remaining == 0
    STDERR.puts "Fetching page... #{options.inspect}"
    json = ""
    req = Net::HTTP.start('twitter.com') do |http|
      http.read_timeout = 600
      response = http.get(page_path(options))
      @requests_remaining = response["x-ratelimit-remaining"].to_i
      json = JSON.parse(response.body)
    end
    json
  end

  def download_in_reply_to(options = {})
    return if @requests_remaining == 0
    count = 0
    Dir.glob("#{tweet_dir}/*").each do |file|
      tweet = JSON.parse(File.read(file))
      if id = tweet["in_reply_to_status_id"]
        unless File.exist?(filename_for_id(id))
          tweet = fetch_one_tweet(id)
          return count if tweet.nil?
          save_tweets [tweet]
          sleep(SLEEPY_TIME)
          count += 1
        end
      end      
    end
    return count + download_in_reply_to(options) unless count == 0
  end

  def fetch_one_tweet(id)
    puts "@requests_remaining " + @requests_remaining.to_s
    return if @requests_remaining == 0
    STDERR.puts "Fetching tweet #{id}..."
    json = ""
    req = Net::HTTP.start('api.twitter.com') do |http|
      http.read_timeout = 600
      response = http.get(show_path(:id => id, :include_entities => true))
      @requests_remaining = response["x-ratelimit-remaining"].to_i
      json = JSON.parse(response.body)
    end
    json
  end
end
