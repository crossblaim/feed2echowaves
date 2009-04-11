require 'rubygems'
require 'oauth'
require 'feedzirra'

##
# Please, supply all the configuration parameters below
#
# FEED:             the feed you want to publish to EchoWaves, can be any atom or rss feed
#
# METADATA_FILE:    in this file the program keeps the information of the already published feed entries
#
# TOKENS_FILE:      after the user allows the program to access EchoWaves through OAuth,
#                   the program keep the tokens in this file
# 
# ECHOWAVES_URL:    the url of your echowaves installation
#
# CONVO_ID:         the id of the convo where the feed will be published
#
# CONSUMER_KEY:     register your app in ECHOWAVES_URL/oauth_clients to get your consumer key
#
# CONSUMER_SECRET:  register your app in ECHOWAVES_URL/oauth_clients to get your secret key
#
FEED = 
METADATA_FILE = "feed2echowaves.metadata"
TOKENS_FILE = "feed2echowaves.tokens"
ECHOWAVES_URL = "http://echowaves.com"
CONVO_ID = 
CONSUMER_KEY = 
CONSUMER_SECRET = 
# end of the user configuration


metadata = if File.exists?(METADATA_FILE)
  Marshal.load( File.read(METADATA_FILE) )
else
  Hash.new( Time.at(0) )
end

tokens = if File.exists?(TOKENS_FILE)
  Marshal.load( File.read(TOKENS_FILE) )
else
  Hash.new
end

consumer = OAuth::Consumer.new(
  CONSUMER_KEY, 
  CONSUMER_SECRET, 
  {:site => ECHOWAVES_URL}
)

def get_access_token(consumer, tokens)
  if tokens['atoken'] && tokens['asecret']
    access_token = OAuth::AccessToken.new(consumer, tokens['atoken'], tokens['asecret'])
    return access_token

  elsif tokens['rtoken'] && tokens['rsecret']
    request_token = OAuth::RequestToken.new(consumer, tokens['rtoken'], tokens['rsecret'])
    access_token = request_token.get_access_token
    tokens['atoken'] = access_token.token
    tokens['asecret'] = access_token.secret
    tokens.delete('rtoken')
    tokens.delete('rsecret')
    File.open( TOKENS_FILE, 'w' ) do|f|
      f.write Marshal.dump(tokens)
    end
    return access_token
    
  else
    request_token = consumer.get_request_token
    tokens['rtoken'] = request_token.token
    tokens['rsecret'] = request_token.secret
    File.open( TOKENS_FILE, 'w' ) do|f|
      f.write Marshal.dump(tokens)
    end
    # authorize in the browser
    %x(open #{request_token.authorize_url})
    exit
  end
end


access_token = get_access_token(consumer, tokens)

feed = Feedzirra::Feed.fetch_and_parse( FEED )

feed.entries.reverse.each_with_index do|i,idx|
  if i.published > metadata[FEED]
    text = "#{i.title}\n#{i.url}"

    access_token.post("#{ECHOWAVES_URL}/conversations/#{CONVO_ID}/messages.xml", "message[message]=#{text}")
    
    metadata[FEED] = i.published
    File.open( METADATA_FILE, 'w' ) do|f|
      f.write Marshal.dump(metadata)
    end

    sleep 5
  end
end