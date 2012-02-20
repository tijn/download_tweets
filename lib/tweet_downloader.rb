#!/usr/bin/env ruby
require 'rubygems'
require 'net/http'
require 'json'
require 'twitter'


class TweetDownloader
  attr_reader :user, :tweet_dir

  def initialize(username, directory)
    raise "username is incorrect: #{username.inspect}" if username.nil? or username.empty?
    @user = username
    @tweet_dir = directory
  end

  # I just realized that I don't know for sure if status ids are increasing...
  def latest_downloaded
    Dir.glob("#{tweet_dir}/*.json").map { |f| File.basename(f, ".json").to_i rescue 1 }.max
  end

  def fails
    @fails ||= Dir.glob("#{tweet_dir}/*.fail").map { |f| File.basename(f, ".fail").to_i }
  end

  def go(options = {})
    download_tweets(options)
    download_in_reply_to(options)
  end

  def download_tweets(options = {})
    options[:since_id] ||= latest_downloaded
    options[:count] ||= 100
    tweets = fetch_page(options)
    STDERR.puts "#{tweets.size} tweets"
    save_tweet(*tweets)
    unless tweets.empty?
      # twitter starts counting pages at 1 (not at zero)
      download_tweets(options.merge(:page => (options[:page] || 1) + 1))
    end
  end

  def filename(status)
    filename_for_id(status.id)
  end

  def filename_for_id(id)
    "#{tweet_dir}/#{id}.json"
  end

  def filename_for_fail(id)
    "#{tweet_dir}/#{id}.fail"
  end

  def save_tweet(*tweets)
    tweets.each do |status|
      next if File.exists?(filename(status))
      File.open(filename(status), 'w') { |f| f.puts status.attrs.to_json }
      STDERR.puts "#{status.created_at}\t#{status.user.screen_name}: #{status.text}"
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

  def fetch_page(options = {})
    Twitter.user_timeline(user, options).each do |status|
      yield status if block_given?
    end
  end

  def download_in_reply_to(options = {})
    count = 0
    Dir.glob("#{tweet_dir}/*.json").each do |file|
      tweet = JSON.parse(File.read(file, :encoding => 'utf-8'))
      if id = tweet["in_reply_to_status_id"]
        next if File.exist?(filename_for_id(id)) 
        next if fails.include?(id)
        status = fetch_one_tweet(id)
        next if status.nil?
        save_tweet status
        count += 1
      end      
    end
    count
  end

  def fetch_one_tweet(id)
    Twitter.status(id)
  rescue Twitter::Error => error
    File.open(filename_for_fail(id), 'w') { |f| f.puts error }
    return nil
  rescue
    STDERR.puts "error downloading #{id}", $!
    raise
  end
end
