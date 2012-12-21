require 'koala'

module Utilities
  module Facebook
    class FbGraphUtil

      include Koala

      def initialize(token)
        init_fb_graph(token)
        initialize_objects_for_friends_stats
      end

      #
      # Returns status/post, photos and links count map with following values,
      #   :total_characters, :total_statuses, :total_likes, :total_comments, :avg_char_length, :total_photos, :total_links
      #
      # @param since
      # @param until
      # @param uid
      def get_user_activity_map(uid, until_dt=Date.today, since_dt=Date.today.advance(years: -2))

        debug "ENTER :: ==> get_user_activity_map(uid, since_date, until_date)"
        since_date = since_dt.to_formatted_s(:db)
        until_date = until_dt.to_formatted_s(:db)
        info "Since_date = #{since_date}, Until_date = #{until_date}"

        status_activity_map = fetch_status_activity_details(uid, since_date, until_date)
        photos_activity_map = fetch_photos_activity_details(uid, since_date, until_date)
        links_activity_map = fetch_links_activity_details(uid, since_date, until_date)

        info  "get_user_activity_map values : #{@user_status_map.inspect}"
        debug "EXIT :: ==> get_user_activity_map(uid, since_date, until_date)"
        status_activity_map.merge(photos_activity_map).merge(links_activity_map)
      end

      #
      # Returns <code>Hash</code> with following keys ,
      #
      #   :gender_map (Count of male/female friends),
      #   :age_map (Age range count of friends),
      #   :location_map (Location based count, for each location),
      #   :relationship_status_map (Relationship status based count)
      #

      def generate_friends_stats_map(user_id)
        debug "ENTER :: ==> generate_friends_stats_map(user_id)"
        @stats_map = {}
        begin
          @friends_profile = graph.get_connections("#{user_id}", "friends", "fields" => "birthday,gender,relationship_status,location")
          @friends_profile.each do |friend|
            generate_friends_gender_map(friend)
            generate_friends_relationship_map(friend)
            generate_friends_age_map(friend)
          end
          friends_locations_map = friends_locations_map(user_id)
          debug "EXIT :: ==> generate_friends_stats_map(user_id)"
          @stats_map = {
              gender_map: friends_gender_map,
              relationship_status_map: friends_relationship_map,
              age_map: friends_age_map
          }.merge(friends_locations_map)
          #debug " =====================> #{@stats_map.inspect}"
        rescue Exception => e
          error("generate_friends_stats_map :: #{e.message}")
        end
        @stats_map
      end

      ###################################################################################################

      private

      ###################################################################################################

      # For activity stats.start ######################################
      def get_status_action_count(user_statuses, action)
        user_statuses.select { |status|
          status[action].present? && status[action]['data'].present?
        }.collect {|status| status[action]['data'].size
        }.inject{|sum, count| sum+count}
      end

      def get_status_message_char_count(user_statuses)
        user_statuses.select{|status|
          status['message'].present?
        }.collect{|status| status['message'].length
        }.inject(0){|sum, msg_len| sum + msg_len}
      end

      def fetch_status_activity_details(uid,since_date,until_date)
        debug "ENTER :: ==> fetch_status_activity_details(uid,since_date,until_date)"
        total_msg = 0
        total_likes = 0
        total_comments = 0
        total_char_count = 0
        total_posts = 0
        total_statuses = 0

        begin
          info "Fetching status information...."
          user_statuses = graph.get_connections(uid, "statuses",{
              fields:"id, message", limit: '200',  until: until_date
          })
          page = 0
          if user_statuses.present?
            page +=1
            #info  "Fetching data for page: #{page} ..."

            total_statuses+= user_statuses.size
            #user_statuses = user_statuses.next_page
          end

          #Fetching posts, comments and likes...
          info "Fetching posts information...."
          user_posts = graph.get_connections(uid, "posts",{
              fields:"id, message, likes.limit(200).fields(id), comments.limit(200).fields(id)",
              limit: '200',  until: until_date
          })
          page = 0
          if user_posts.present?
            page +=1
            #info  "Fetching data for page: #{page} ..."

            posts = user_posts.select{|status| status['message'].present?}.size
            total_posts+= posts
            total_msg += posts
            total_likes += get_status_action_count(user_posts, 'likes')
            total_comments += get_status_action_count(user_posts, 'comments')
            total_char_count += get_status_message_char_count(user_posts)

            #user_posts = user_posts.next_page
          end
          debug "EXIT :: ==> fetch_status_activity_details(uid,since_date,until_date)"
        rescue Exception => e
          error "fetch_status_activity_details : #{e.message}"
        end

        {
            total_characters: total_char_count,
            total_statuses: total_statuses,
            total_posts: total_posts,
            total_likes: total_likes ,
            total_comments: total_comments,
            avg_char_length: total_msg>0 ? (total_char_count/total_msg) : 0
        }
      end

      def fetch_photos_activity_details(uid,since_date,until_date)
        total_photos = 0
        begin
          info " Fetching photos information....until #{until_date}"
          user_photos = graph.get_connections(uid, "photos",{
              fields:"id", type:'uploaded',
              limit: '200',  until: until_date
          })
          total_photos = calculate_activity_count(user_photos)
        rescue Exception => e
          error "fetch_photos_activity_details : #{e.message}"
        end

        { total_photos: total_photos  }
      end

      def fetch_links_activity_details(uid,since_date,until_date)
        total_links = 0
        begin
          info " Fetching Links information...."
          user_links = graph.get_connections(uid, "links",{
              fields:"id",
              limit: '1000', until: until_date
          })
          total_links = calculate_activity_count(user_links)
        rescue Exception => e
          error "fetch_photos_activity_details : #{e.message}"
        end

        {total_links: total_links}
      end

      def calculate_activity_count(fb_activity_results)
        page = 0
        total_count = 0
        while fb_activity_results.present?
          page +=1
          info "Fetching data for page: #{page} ..."
          total_count+= fb_activity_results.size
          fb_activity_results = fb_activity_results.next_page
        end
        total_count
      end

      #For activity stats.end######################################

      #For friends stats.start ######################################
      def friends_locations_map(uid)
        fql_curr_location = "SELECT current_location.state,current_location.country FROM user WHERE uid in (SELECT uid2 FROM friend where uid1 = #{uid} )"
        friends_location_map = graph.fql_query(fql_curr_location)
        country_map = {}
        states_map = {}
        if friends_location_map.present?
          friends_location_map.each do |location|
            curr_location = location['current_location']
            if curr_location.present? && curr_location['state'].present? && curr_location['country'].present?
              state = curr_location['state']
              country= curr_location['country']

              if country_map[country.to_sym].present?
                country_map[country.to_sym] += 1
              else
                country_map[country.to_sym] = 1
              end

              if states_map[state.to_sym].present?
                states_map[state.to_sym] += 1
              else
                states_map[state.to_sym] = 1
              end
            end
          end
        end
        {country_map: country_map, state_map: states_map }
      end

      def friends_gender_map
        { male: @male_count, female: @female_count, undefined: @undefined_gender_count }
      end

      def friends_relationship_map
        {
            married: @married_count,
            single: @single_count,
            complicated: @its_complicated_count,
            other: @other_count,
            open: @open_relationship_count,
            engaged: @engaged_count,
            in_relation: @in_relationship_count
        }
      end

      def friends_location_map
        @location_map = {}
        @friends_location.values.each do |val_map|
          @location_map[val_map['location_name']] = val_map['count']
        end
        @location_map
      end

      def friends_age_map
        @friends_age_map
      end

      def generate_friends_age_map(friend)
        if friend["birthday"].present?
          age = age_in_years(friend["birthday"])
          if(age>0 && age<18)
            @friends_age_map[:'1-17'] += 1
          elsif(age>17 && age<25)
            @friends_age_map[:'18-24'] += 1
          elsif(age>24 && age<35)
            @friends_age_map[:'25-34'] += 1
          elsif(age>34 && age<45)
            @friends_age_map[:'35-44'] += 1
          elsif(age>44 && age<55)
            @friends_age_map[:'45-54'] += 1
          elsif(age>54 && age<65)
            @friends_age_map[:'55-64'] += 1
          elsif(age>=65)
            @friends_age_map[:'65+'] += 1
          else
            @friends_age_map[:undefined] += 1
          end
        end
      end

      def generate_friends_relationship_map(friend)
        unless friend["relationship_status"].nil?
          case friend["relationship_status"]
            when "Married"
              @married_count += 1
            when "Single"
              @single_count += 1
            when "It's complicated"
              @its_complicated_count += 1
            when "In a relationship"
              @in_relationship_count += 1
            when "In an open relationship"
              @open_relationship_count += 1
            when "Engaged"
              @engaged_count += 1
          end
        else
          @other_count += 1
        end
      end

      def initialize_objects_for_friends_stats
        #For Gender
        @male_count = 0
        @female_count = 0
        @undefined_gender_count = 0

        #For relationships
        @married_count = 0
        @single_count = 0
        @its_complicated_count = 0
        @other_count = 0
        @open_relationship_count = 0
        @engaged_count = 0
        @in_relationship_count = 0

        @friends_location = {}
        @friends_age_map = {}
        @friends_age_map = {:'undefined' => 0, :'1-17' =>  0, :'18-24' =>  0, :'25-34' =>  0,:'35-44' =>  0,
                            :'45-54' =>  0,:'55-64' =>  0,:'65+' =>  0 }
      end

      def generate_friends_gender_map(friend)
        unless friend["gender"].nil?
          if friend["gender"] == "male"
            @male_count += 1
          elsif friend["gender"] == "female"
            @female_count += 1
          end
        else
          @undefined_gender_count += 1
        end
      end

      # For friends stats.end ######################################

      #
      # Returns user details for given user_id, based on given fields
      # @param uid
      # @param fields
      #
      def get_user_profile(uid,fields)
        begin
          @user_details = graph.get_object("#{uid}","fields" => "#{fields}")
        rescue Exception => e
          error("get_user_profile :: #{e.message}")
        end
      end

      def graph
        @graph
      end

      def init_fb_graph(token)
        begin
          @graph = @graph || Koala::Facebook::API.new("#{token}")
        rescue Exception => e
          error("init_fb_graph :: #{e.message} ")
        end
      end

      def age_in_years(birth_date_str)
        return 0 if (!birth_date_str.present? || birth_date_str.split('/').size<3)
        birth_date = Date.strptime birth_date_str, '%m/%d/%Y'
        return 0 if birth_date > Date.today
        Date.today.year - birth_date.year
      end

      #### print methods
      def debug(msg)
        Rails.logger.debug msg
        puts "DEBUG :: #{msg}" if Rails.env.development?
      end

      def info(msg)
        Rails.logger.info msg
        puts "INFO :: #{msg}" if Rails.env.development?
      end

      def error(msg)
        Rails.logger.error "ERROR :: #{msg}"
        puts "ERROR :: #{msg}" if Rails.env.development?
      end
    end
  end
end