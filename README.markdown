Twitter Links
========

Twitter Links is a tools to grab all links shared by your friends on Twitter.


Dependances
-----------------

* sinatra
* redis
* twitter_oauth


Setup
-----------------

1. Install ruby and all dependancies (see above)

2. Create a [Twitter app](https://dev.twitter.com/apps/new) and get an API key and a secret

3. Copy config file:

        cp config.yml-dist config.yml

4. Edit `config.yml` to add your Twitter API key and your secret:

        consumer_key: #TWITTER_CONSUMER_KEY#
        consumer_secret: #TWITTER_CONSUMER_SECRET#

5. Launch application:

        ruby app.rb

6. Go to [http://localhost:4567](http://localhost:4567) and sign-in

7. Run crawler:

        ruby crawler.rb

8. Refresh [http://localhost:4567](http://localhost:4567)
