# encoding: UTF-8

xml.instruct! :xml, :version => '1.0'
xml.rss :version => '2.0' do
    xml.channel do
        xml.title 'TwitterRss'
        xml.link @home
        xml.description 'Turn your friends timeline into RSS'
        xml.lastBuildDate @user.crawled_at.rfc2822
        @links.each do |link|
            xml.item do
                xml.title link.title.force_encoding 'UTF-8'
                xml.description link.content.force_encoding 'UTF-8'
                xml.pubDate link.date.rfc2822
                xml.link link.url
                xml.guid link.id
                link.images.each do |image|
                    xml.enclosure do
                        xml.url image
                    end
                end
            end
        end
    end
end
