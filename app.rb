# encoding: UTF-8

require 'sinatra'
require 'erb'
require './twitter-rss'

configure do
    set :sessions, true
end

before do
    @home = request.scheme + '://' + request.host + ':' + request.port.to_s
    if not session[:user_id].nil? then
        @user = TwitterRss::User.new session[:user_id]
        @twitter = @user.twitter
    else
        @twitter = TwitterRss::Twitter.new
    end
end

get '/' do
    if not @user.nil? then
        redirect to '/links'
    else
        redirect to '/connect'
    end
end

get '/connect' do
    request_token = @twitter.request_token(
        :oauth_callback => @home + '/auth'
    )
    session[:request_token] = request_token.token
    session[:request_token_secret] = request_token.secret
    redirect request_token.authorize_url
end

get '/auth' do
    begin
        access_token = @twitter.authorize(
            session[:request_token],
            session[:request_token_secret],
            :oauth_verifier => params[:oauth_verifier]
        )

        if @twitter.authorized? then
            info = @twitter.info

            user = TwitterRss::User.new info['screen_name']
            user.token = access_token.token
            user.secret = access_token.secret

            session[:user_id] = user.id

            redirect '/links'
        else
            redirect '/'
        end
    rescue Exception => e
        redirect '/disconnect'
    end
end

get '/disconnect' do
    session[:user_id] = nil
    session[:request_token] = nil
    session[:request_token_secret] = nil
    redirect '/'
end

get '/links' do
    redirect to '/links/1'
end

get '/links/:page' do |page|
    if @user.nil? then
        redirect to '/'
    end

    range = 10
    @page = page.to_i
    @pages = (@user.timeline.length.to_f / range).ceil

    start = (@page - 1) * range
    stop = start + range - 1
    @links = @user.timeline.get start, stop
    erb :links
end

get '/feed/:user_id/:token' do |user_id,token|
    @user = TwitterRss::User.new user_id
    if @user.feed_token != token then
        halt 403, 'Forbidden!'
    end
    @links = @user.timeline.get 0, 20
    builder :feed
end

get '/feed/reset_token' do
    if not @user.nil? then
        @user.reset_feed_token
    end
    redirect to '/'
end

helpers do

    def ago(date)
        diff = Time.now.to_f - date.to_f
        if diff < 60 then
            return diff.ceil.to_s + " second(s) ago"
        end
        diff = diff / 60
        if diff < 60 then
            return diff.ceil.to_s + " minute(s) ago"
        end
        diff = diff / 69
        if diff < 24 then
            return diff.ceil.to_s + " hour(s) ago"
        end
        diff = diff / 24
        return diff.ceil.to_s + " day(s) ago"
    end

end
