# encoding: UTF-8

require 'sinatra'
require 'erb'
require './lib/user'
require './lib/config'
require 'twitter_oauth'

configure do
    set :sessions, true
end

before do
    @home = request.scheme + '://' + request.host + ':' + request.port.to_s

    config = TwitterLinks::Config.get
    options = {
        :consumer_key => config['twitter_consumer_key'],
        :consumer_secret => config['twitter_consumer_secret'],
    }
    if not session[:user_id].nil? then
        @user = TwitterLinks::User.get session[:user_id]
        if not @user.nil? then
            options[:token] = @user.token
            options[:secret] = @user.secret
        end
    end
    @twitter = TwitterOAuth::Client.new options
end

get '/' do
    if @user.nil? then
        redirect to '/connect'
    end

    if params.has_key? 'page' and not params['page'].empty? then
        @page = params['page'].to_i
    else
        @page = 1
    end

    if params.has_key? 'search' and not params['search'].empty? then
        @search = params['search']
    else
        @search = '*'
    end

    if params.has_key? 'count' and not params['count'].empty? then
        count = params['count']
    else
        count = 25
    end

    start = (@page - 1) * count
    stop = start + count - 1
    @links = @user.links @search, start, stop

    total = @user.count_links @search
    @pages = (total.to_f / count).ceil

    erb :index
end

get '/feed/:user_id/:token' do |user_id, token|
    @user = TwitterLinks::User.get user_id
    if @user.secret != token then
        halt 403, 'Forbidden!'
    end

    if params.has_key? 'search' and not params['search'].empty? then
        search = params['search']
    else
        search = '*'
    end

    if params.has_key? 'count' and not params['count'].empty? then
        count = params['count']
    else
        count = 25
    end

    @links = @user.links search, 0, count, 'date:desc'
    builder :feed
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
            id = info['id'].to_s

            user = TwitterLinks::User.get id
            if user.nil? then
                user = TwitterLinks::User.new id
                user.screen_name = info['screen_name']
                user.token = access_token.token
                user.secret = access_token.secret
                user.save
            end

            session[:user_id] = user.id

            redirect '/'
        else
            redirect '/connect'
        end
    rescue Exception => e
        puts e
        redirect '/disconnect'
    end
end

get '/disconnect' do
    session[:user_id] = nil
    session[:request_token] = nil
    session[:request_token_secret] = nil
    redirect '/'
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

    def query(data)
        result = request.env['rack.request.query_hash'].clone
        data.each do |key, value|
            result[key] = value
        end

        values = []
        result.each do |key, value|
            values << key + '=' + URI::encode(value.to_s)
        end

        '?' + values.join('&')
    end

    def tweet(text)
        text = text.gsub(%r{(https?://t.co/\w+)}, '<a target="_blank" href="\1">\1</a>')
        text = text.gsub(%r{@(\w+)}, '<a href="?search=user:\1">@\1</a>')
        text = text.gsub(%r{#(\w+)}, '<a href="?search=tag:\1">#\1</a>')
    end

end
