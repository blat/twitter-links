# encoding: UTF-8

xml.instruct! :xml, :version => '1.0'
xml.rss :version => '2.0' do
    xml.channel do
        xml.title 'Twitter Links'
        xml.description 'All your Twitter links in a same place'
        xml.link @home
        xml.lastBuildDate Time.at(@user.get('crawled_at').to_i).rfc2822
        xml.author @user.to_s
        @links.each do |link|
            xml.item do
                xml.link link.get('url')
                xml.guid link.id
                xml.title link.get('title')
                xml.pubDate Time.at(link.get('date').to_i).rfc2822
                if link.is_html? then
                    xml.description link.get('content')
                else
                    xml.enclosure do
                        xml.url link.get('url')
                    end
                end
            end
        end
    end
end
