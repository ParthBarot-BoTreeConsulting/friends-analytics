require 'utilities/facebook/fb_graph_util'
require 'gchart'

class HomeController < ApplicationController

  include Utilities::Facebook

  def index
    if user_signed_in?
      fb_auth = current_user.authentications.find_by_provider(:facebook)
      if fb_auth.present?
        fb_util = Utilities::Facebook::FbGraphUtil.new(fb_auth.token)
        @friends_stats_map = fb_util.generate_friends_stats_map(fb_auth.uid)
        @activity_stats_map = fb_util.get_user_activity_map(fb_auth.uid)

        fb_analytics_json_map = {
            friends_stats_map: @friends_stats_map,
            activity_stats_map: @activity_stats_map
        }
        @total_users =  @friends_stats_map[:gender_map].values.inject{|s,n| s+n}

        activity_data = { photos: @activity_stats_map[:total_photos],
                   statuses:@activity_stats_map[:total_statuses],
                   links:@activity_stats_map[:total_links] }
        @activity_graph = get_google_new_pie_chart(activity_data, 'F8F8F8', "Activity") if(@activity_stats_map.present? && @activity_stats_map.size>=3)

        @top_countries_graph = get_google_new_pie_chart(@friends_stats_map[:country_map],'F8F8F8', "Top Countries", 600, 250 )

        @top_states_graph = get_google_new_pie_chart(@friends_stats_map[:state_map], 'F8F8F8', "Top States",600, 250)


        if @friends_stats_map.present? && @friends_stats_map.size>0
          @friends_gender_graph = get_google_new_pie_chart(@friends_stats_map[:gender_map], 'F8F8F8', "Friends' Gender")
          @friends_status_graph = get_google_new_pie_chart(@friends_stats_map[:relationship_status_map],'F8F8F8',"Friends' Relationship")
          @friends_age_graph = get_google_new_pie_chart(@friends_stats_map[:age_map],'F8F8F8',"Friends' Age")

        end
      end
    end
  end


  ################################# Twitter section

  def process_tweets
    twitter_auth = current_user.authentications.find_by_provider(:twitter)

    if twitter_auth
      twitter = Twitter::Client.new(:oauth_token => twitter_auth.token,
                                    :oauth_token_secret => twitter_auth.secret)

      @tweets_analysis = TweetsAnalysis.new(params[:twitter_handle], twitter_auth.token, twitter_auth.secret)
      @tweets_analysis.analyze
      puts @tweets_analysis.profile.inspect
    end
    #retweets = Array.new
    #
    #@tweets_retweets_arr = Array.new
    #twitter_auth = current_user.authentications.find_by_provider(:twitter)
    #
    #if twitter_auth
    #  twitter = Twitter::Client.new(:oauth_token => twitter_auth.token,
    #                                :oauth_token_secret => twitter_auth.secret)
    #
    #  tweets = twitter.user_timeline(params[:twitter_handle], :page => 1, :count => 5)
    #
    #  tweets.each do |tweet|
    #    tweet_embedded_urls = URI.extract(tweet.text)
    #    retweet_ids = get_retweet_ids(twitter, tweet.id)
    #    tweets_retweets = TweetsRetweets.new(tweet.id, tweet.text, tweet_embedded_urls, retweet_ids)
    #    @tweets_retweets_arr << tweets_retweets
    #  end
    #
    #  return @tweets_retweets_arr
    #end
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

  private

  def get_activity_pie_chart(activity_stats_map)

    get_google_pie_chart_url(legend, data, '1277bd', 'F8F8F8')
  end

  def get_google_pie_chart_url(fb_data_map,colors='a4a5de',bg_color='F8F8F8',size='200x120', title='')
    total_score = fb_data_map.values.inject(0){|s,n| s+n}
    legend = fb_data_map.collect{|key,val| "#{key} (#{val} - #{(val*100/total_score.to_f).round(1)}%)"}
    data = fb_data_map.values
    Gchart.pie(title: title, legend: legend.collect{|ele| ele.humanize()}, data: data, size: size, bar_colors: colors, bg_color: bg_color)
  end

  def get_google_bar_chart_url(legend, data,colors='a4a5de',bg_color='FFFFFF',size='200x120', title='')
    Gchart.bar(title: title, legend: legend.collect{|ele| ele.humanize()}, data: data, size: size, bar_colors: colors, bg_color: bg_color, bar_width_and_spacing: '25,6')
  end

  def get_google_new_pie_chart(fb_data_map, bg_color='F8F8F8',title='',width=400, height=250)

    #total_score = fb_data_map.values.inject(0){|s,n| s+n}
    #legend = fb_data_map.collect{|key,val| "#{key} (#{val} - #{(val*100/total_score.to_f).round(1)}%)"}
    #data = fb_data_map.values

    data_table = GoogleVisualr::DataTable.new

    # Add Column Headers
    data_table.new_column('string', 'one' )
    data_table.new_column('number', 'two' )
    # Add Rows and Values
    data_table.add_rows(fb_data_map.collect{|k,v| [k.to_s.humanize, v]})

    option = { width: width, height: height, title: title, is3D: true, backgroundColor: bg_color,chartArea:{left:30}}
    @chart = GoogleVisualr::Interactive::PieChart.new(data_table, option)

  end

end

########################################################################################################################
class TweetsAnalysis

  include Twitter

  TWEETS_PER_PAGE = 200
  attr_accessor :profile, :statistics

  def initialize(screen_name_or_user_id, oauth_token, oauth_token_secret)
    @screen_name_or_user_id = screen_name_or_user_id

    @twitter_client = Twitter::Client.new(
        :oauth_token => oauth_token,
        :oauth_token_secret => oauth_token_secret
    )
  end


  def fetch_by_page(page_num)
    puts("Processing Page No :: #{page_num}")
    @twitter_client.user_timeline(@screen_name_or_user_id, :page => page_num, :count => TWEETS_PER_PAGE)
  end

  def analyze
    puts("Analysis started.....")
    tweets = fetch_by_page(1)

    if tweets && tweets.any?
      user = tweets.first.user
      total_tweets = user.statuses_count
      total_tweets = total_tweets > 3200 ? 3200 : total_tweets
      total_pages = total_tweets % TWEETS_PER_PAGE == 0 ? total_tweets / TWEETS_PER_PAGE : total_tweets / TWEETS_PER_PAGE + 1

      #Profile
      @profile = Profile.new(user)

      #Statistics
      @statistics = Statistics.new(user)

      @statistics.merge(tweets) #for first page

      if total_pages > 1
        (2..total_pages).each do |page_num|
          @statistics.merge(fetch_by_page(page_num))
        end
      end
    else
      puts("User doesn't have any tweets to analyze")
      #TODO : What if there is no tweet?
    end
    puts("Analysis finished.....")
  end
end

class Profile
  attr_accessor :profile_image_url, :screen_name, :name, :joined_on, :time_zone, :location, :bio, :website_url, :lang

  def initialize(user)
    @profile_image_url = user.profile_image_url
    @screen_name = user.screen_name
    @name = user.name
    @joined_on = user.created_at.to_datetime
    @location = user.location
    @time_zone = user.time_zone
    @lang = user.lang
    @bio = user.description
    @website_url = user.url
  end

  def to_s
    "Name: #{name}, Screen Name: #{screen_name}, Joined On: #{joined_on}, Location: #{location}, Timezone: #{time_zone}, Language: #{lang}, Bio: #{bio}, URL: #{website_url}"
  end
end

class Statistics
  attr_accessor :tweets, :followers, :following, :listed, :tweets_analyzed,
                :retweets_count, :tweets_with_links, :tweets_with_media,
                :tweets_with_hashtag, :tweets_with_mentions

  def initialize(user)
    @tweets = user.statuses_count
    @followers = user.followers_count
    @following = user.friends_count
    @listed = user.listed_count
    @tweets_analyzed = @retweets_count = @tweets_with_links = @tweets_with_media = 0
    @tweets_with_hashtag = @tweets_with_mentions = 0
    @hashtags = []
    @mentions = []
  end

  def merge(tweets)

    self.tweets_analyzed = tweets_analyzed + tweets.size

    tweets.each do |tweet|

      if tweet.retweeted_status
        self.retweets_count = retweets_count + 1
      end

      if tweet.urls.any?
        self.tweets_with_links = tweets_with_links + 1
      end

      if tweet.media.any?
        self.tweets_with_media = tweets_with_media + 1
      end

      if tweet.hashtags.any?
        self.tweets_with_hashtag = tweets_with_hashtag + 1
        tweet.hashtags.each do |tag|
          @hashtags << tag.text
        end
      end

      if tweet.user_mentions.any?
        self.tweets_with_mentions = tweets_with_mentions + 1
        tweet.user_mentions.each do |mention|
          @mentions << mention.screen_name
        end
      end
    end
  end

  def followers_ratio
    (followers / following.to_f).round(2)
  end

  def hashtags
    @hashtags.uniq
  end

  def mentions
    @mentions.uniq
  end

  def hashtags_with_count
    count_occurance(@hashtags)
  end

  def mentions_with_count
    count_occurance(@mentions)
  end

  def to_s
    "Statistics :: Tweets #: #{tweets}, Followers #: #{followers}, Following #: #{following}, Followers ratio: #{followers_ratio}, Listed #: #{listed} \
    tweets_analyzed #: #{tweets_analyzed}, retweets_count #: #{retweets_count}, tweets_with_links #: #{tweets_with_links} \
    tweets_with_media #: #{tweets_with_media}, tweets_with_hashtag #: #{tweets_with_hashtag}, tweets_with_mentions #: #{tweets_with_mentions}"
  end

  private
  def count_occurance(tuples_array)
    tuples_array.inject(Hash.new(0)) { |h, i| h[i] += 1; h }
  end
end