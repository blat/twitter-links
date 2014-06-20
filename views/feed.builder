# encoding: UTF-8

xml.instruct! :xml, :version => '1.0'
xml.rss :version => '2.0' do
    xml.channel do
        xml.title 'Twitter Links'
        xml.description 'All your Twitter links in a same place'
        xml.link @home
        xml.lastBuildDate Time.at(@user.crawled_at.to_i).rfc2822
        xml.author @user.screen_name
        @links.each do |link|
            xml.item do
                xml.link link.url
                xml.guid link.id
                xml.title link.title
                xml.pubDate Time.at(link.date.to_i).rfc2822
                xml.description link.content
                if link.thumbnail then
                    xml.enclosure do
                        xml.url link.thumbnail
                    end
                end
            end
        end
    end
end
