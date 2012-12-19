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

        @activity_graph_url = get_activity_pie_chart(@activity_stats_map) if(@activity_stats_map.present? && @activity_stats_map.size>=3)

        @top_countries_graph_url = get_google_pie_chart_url(@friends_stats_map[:country_map].collect{|key,val| "#{key} (#{val})"},
                                                            @friends_stats_map[:country_map].values,
                                                            '1277bd', 'F8F8F8', '350x300', "Top Countries")

        @top_states_graph_url = get_google_pie_chart_url(@friends_stats_map[:state_map].collect{|key,val| "#{key} (#{val})"},
                                                            @friends_stats_map[:state_map].values,
                                                            '1277bd', 'F8F8F8', '350x300', "Top States")


        if @friends_stats_map.present? && @friends_stats_map.size>0
          @friends_gender_graph_url = get_google_pie_chart_url(@friends_stats_map[:gender_map].collect{|key,val| "#{key} (#{val})"},
                                                               @friends_stats_map[:gender_map].values,
                                                               '1277bd', 'F8F8F8', '250x200', "Friends' Genders")
          @friends_status_graph_url = get_google_pie_chart_url(@friends_stats_map[:relationship_status_map].collect{|key,val| "#{key} (#{val})"},
                                                               @friends_stats_map[:relationship_status_map].values,
                                                               '1277bd', 'F8F8F8','250x200',"Friends' Relationships")
          @friends_age_graph_url = get_google_pie_chart_url(@friends_stats_map[:age_map].collect{|key,val| "#{key} (#{val})"},
                                                            @friends_stats_map[:age_map].values,
                                                            '1277bd', 'F8F8F8','250x200',"Friends' Ages")
        end
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

  private

  def get_activity_pie_chart(activity_stats_map)
    legend = ['Photos', 'Statuses', 'links']
    data = [activity_stats_map[:total_photos], activity_stats_map[:total_statuses],activity_stats_map[:total_links]]
    get_google_pie_chart_url(legend, data, '1277bd', 'F8F8F8')
  end

  def get_google_pie_chart_url(legend, data,colors='a4a5de',bg_color='F8F8F8',size='200x120', title='')
    Gchart.pie(title: title, legend: legend.collect{|ele| ele.humanize()}, data: data, size: size, bar_colors: colors, bg_color: bg_color)
  end

  def get_google_bar_chart_url(legend, data,colors='a4a5de',bg_color='FFFFFF',size='200x120', title='')
    Gchart.bar(title: title, legend: legend.collect{|ele| ele.humanize()}, data: data, size: size, bar_colors: colors, bg_color: bg_color, bar_width_and_spacing: '25,6')
  end
end
