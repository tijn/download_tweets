#!/usr/bin/env ruby
require 'rubygems'
require 'net/http'
require 'json'


class TweetDownloader
  attr_reader :user, :tweet_dir

  def initialize(username, directory)
    raise "username is incorrect: #{username.inspect}" if username.nil? or username.empty?
    @user = username
    @tweet_dir = directory
  end

  def since_id
    File.basename(Dir.glob("#{tweet_dir}/*.json").sort.last, ".json") rescue 1
  end

  def download_tweets(options = {})
    options[:since_id] ||= since_id
    options[:count] ||= 100
    tweets = fetch_page(options)
    STDERR.puts "#{tweets.size} tweets"
    save_tweets(tweets)
    unless tweets.empty?
      # twitter wants 150 requests per hour at max, we're being nice, so we sleep about 30 seconds before doing a new request
      sleep (3600 / 120)
      # twitter starts counting pages at 1 (not a zero)
      download_tweets(options.merge(:page => (options[:page] || 1) + 1))
    end
  end

  def filename(tweet)
    "#{tweet_dir}/#{tweet["id"]}.json"
  end

  def save_tweets(tweets)
    tweets.each do |tweet|
      next if File.exists?(filename(tweet))
      File.open(filename(tweet), 'w') do |f|
        f.puts tweet.to_json
      end
    end
  rescue
    STDERR.puts tweets.inspect
    raise
  end

  def page_path(options = {})
    path = "/statuses/user_timeline/#{@user}.json"
    unless options.empty?
      opts = options.to_a.map { |x| "#{x.first}=#{x.last}" }
      "#{path}?#{opts.join("&")}"
    else
      path
    end
  end

  def fetch_page(options = {})
    STDERR.puts "Fetching page... #{options.inspect}"
    json = ""
    req = Net::HTTP.start('twitter.com') do |http|
      http.read_timeout = 600
      response = http.get(page_path(options))
      json = JSON.parse(response.body)
    end
    json
  end
end
