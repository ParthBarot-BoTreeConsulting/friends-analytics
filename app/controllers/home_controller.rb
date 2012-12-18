class HomeController < ApplicationController
  def index
    if user_signed_in?
      fb_auth = current_user.authentications.find_by_provider(:facebook)
      if fb_auth.present?
        token = fb_auth.token
        uid =  fb_auth.uid
        get_fb_graph_api_object(token)
        @user_basic_details = get_user_fb_profile(uid,"")
        @user_statuses = get_user_fb_profile(uid,"statuses")
        @user_links = get_user_fb_profile(uid,"links")
        @user_albums = get_user_fb_profile(uid,"albums")
        #render :text => @user_albums["albums"]["data"].size.inspect and return false
        @user_profile_image = @graph.get_picture(uid,:type=>"large")
        get_fb_friends_profile(uid)
        initialize_objects_for_relationship_status_and_gender()
        @friends_location = {}
        @friends_profile.each do |friend|
          calculate_total_male_female_friends(friend)
          calculate_friends_relationship_status(friend)
          analyse_friends_location(friend)
        end

      end
    end
  end


  def get_fb_graph_api_object(token)
    begin
      @graph = Koala::Facebook::API.new("#{token}")
    rescue Exception => e
      Rails.logger.info("=======================================> Error while initialise graph object: #{e.message} ")
    end
  end

  def get_user_fb_profile(uid,fields)
    begin
      @user_details = @graph.get_object("#{uid}","fields" => "#{fields}")
    rescue Exception => e
      Rails.logger.info("=============================>Error while fetching My facebook profile : #{e.message}")
    end
  end


  def get_fb_friends_profile(uid)
    begin
      @friends_profile = @graph.get_connections("#{uid}", "friends", "fields" => "name,birthday,gender,link,relationship_status,location,picture")
    rescue Exception => e
      Rails.logger.info("======================================> Error while getting friends profile: #{e.message}")
    end
  end

  def analyse_friends_location(friend)
    unless friend["location"].nil?
      if @friends_location.has_key?(friend["location"]["id"])
        @friends_location[friend["location"]["id"]]["count"] = @friends_location[friend["location"]["id"]]["count"] + 1
        @friends_location[friend["location"]["id"]]["location_name"] = friend["location"]["name"]
        @friends_location[friend["location"]["id"]]["picture_urls"] << friend["picture"]["data"]["url"]
      else
        @friends_location[friend["location"]["id"]] = {}
        @friends_location[friend["location"]["id"]]["picture_urls"] = []
        @friends_location[friend["location"]["id"]]["count"] = 1
        @friends_location[friend["location"]["id"]]["location_name"] = friend["location"]["name"]
        @friends_location[friend["location"]["id"]]["picture_urls"] << friend["picture"]["data"]["url"]
      end
    end
  end

  def calculate_friends_relationship_status(friend)
    unless friend["relationship_status"].nil?
      case friend["relationship_status"]
        when "Married"
          @married_count = @married_count + 1
        when "Single"
          @single_count = @single_count + 1
        when "It's complicated"
          @its_complicated_count = @its_complicated_count + 1
        when "In a relationship"
          @relationship_count = @relationship_count + 1
        when "In an open relationship"
          @open_relatonship_count = @open_relatonship_count + 1
        when "Engaged"
          @engaged_count = @engaged_count + 1
      end
    else
      @other_count = @other_count + 1
    end
  end

  def initialize_objects_for_relationship_status_and_gender
    @male_count = 0
    @female_count = 0
    @married_count = 0
    @single_count = 0
    @its_complicated_count = 0
    @other_count = 0
    @open_relatonship_count = 0
    @engaged_count = 0
    @relationship_count = 0
  end

  def calculate_total_male_female_friends(friend)
    unless friend["gender"].nil?
      if friend["gender"] == "male"
        @male_count = @male_count+1

      end
      if friend["gender"] == "female"
        @female_count = @female_count+1
      end
    end
  end

  ################################# Twitter section

  def process_tweets

    retweets = Array.new

    @tweets_retweets_arr = Array.new
    twitter_auth = current_user.authentications.find_by_provider(:twitter)

    if twitter_auth
      twitter = Twitter::Client.new(:oauth_token => twitter_auth.token,
                                    :oauth_token_secret => twitter_auth.secret)

      tweets = twitter.user_timeline(params[:twitter_handle], :page => 1, :count => 5)

      tweets.each do |tweet|
        tweet_embedded_urls = URI.extract(tweet.text)
        retweet_ids = get_retweet_ids(twitter, tweet.id)
        tweets_retweets = TweetsRetweets.new(tweet.id, tweet.text, tweet_embedded_urls, retweet_ids)
        @tweets_retweets_arr << tweets_retweets
      end

      return @tweets_retweets_arr
    end
  end

  def get_retweet_ids(twitter_client, id)
    retweet_ids = Array.new
    retweets = Array.new
    begin
      retweets = twitter_client.retweets(id)
      retweets.each do |retweet|
        retweet_ids << retweet.id
      end
    rescue Exception => e
      puts "Error while fetching Retweets - #{e.message}"
    end
    retweet_ids
  end
end
