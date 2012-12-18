class TweetsRetweets

  attr_accessor :tweet_id, :tweet_text, :tweet_embedded_urls, :retweet_ids

  def initialize(tweet_id, tweet_text, tweet_embedded_urls, retweet_ids)
    @tweet_id = tweet_id
    @tweet_text = tweet_text
    @tweet_embedded_urls = tweet_embedded_urls
    @retweet_ids = retweet_ids
  end
end