Twitter Links
========

Twitter Links is a tools to grab all links shared by your friends on Twitter.


Demo
-----------------

* [twitter.blizzart.net](http://twitter.blizzart.net/)


Setup
-----------------

1. Install bundler:

        gem install bundler

2. Install all dependencies:

        bundle install

3. Create a [Twitter app](https://dev.twitter.com/apps/new) and get an API key and a secret

4. Ask for a [Readability API key](https://www.readability.com/developers/api/parser)

5. Copy config file:

        cp config.yml-dist config.yml

6. Edit `config.yml` to add your API keys:

        twitter_consumer_key: #TWITTER_CONSUMER_KEY#
        twitter_consumer_secret: #TWITTER_CONSUMER_SECRET#
        readability_api_key: #READABILITY_API_KEY#

7. Launch application:

        ruby app.rb

8. Go to [http://localhost:4567](http://localhost:4567) and sign-in

9. Run crawler:

        ruby crawler.rb

10. Refresh [http://localhost:4567](http://localhost:4567)
