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
