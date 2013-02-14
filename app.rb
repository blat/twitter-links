# encoding: UTF-8

require 'sinatra'
require 'erb'
require './twitter-links'

configure do
    set :sessions, true
end

before do
    @home = request.scheme + '://' + request.host + ':' + request.port.to_s
    @twitter = TwitterLinks::Twitter.new
    if not session[:user_id].nil? then
        @user = TwitterLinks::User.new session[:user_id]
        if not @user.has? 'screen_name' then
            @user = nil
        else
            @twitter = @user.twitter
        end
    end
end

get '/' do
    if @user.nil? then
        redirect to '/connect'
    end

    if params.has_key? 'page' then
        @page = params['page'].to_i
    else
        @page = 1
    end

    if params.has_key? 'search' then
        @search = params['search']
    else
        @search = ''
    end

    range = 25
    start = (@page - 1) * range
    stop = start + range - 1
    @links = @user.get_links @search, start, stop

    total = @user.count_links @search
    @pages = (total.to_f / range).ceil

    erb :index
end

get '/feed/:user_id/:token' do |user_id,token|
    @user = TwitterLinks::User.new user_id
    if @user.get('secret') != token then
        halt 403, 'Forbidden!'
    end

    if params.has_key? 'search' then
        search = params['search']
    else
        search = ''
    end

    @links = @user.get_links search
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

            user = TwitterLinks::User.new info['id'].to_s
            user.set 'screen_name', info['screen_name']
            user.set 'token', access_token.token
            user.set 'secret', access_token.secret
            user.save

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

    def query(data, reset = false)

        if reset then
            result = data
        else
            result = request.env['rack.request.query_hash'].clone
            data.each do |key, value|
                result[key] = value
            end
        end

        values = []
        result.each do |key, value|
            values << key + '=' + URI::encode(value.to_s)
        end

        '?' + values.join('&')
    end

    def color(tag)
        result = ""
        tag.scan(/./).each do |char|
            result = result + char.ord.to_s
        end
        result.to_i.to_s(16)[0..5]
    end

end
