require 'set'
require 'uri'
require 'nokogiri'
require 'open-uri'

def crawl_site( starting_at, &each_page )
  files = %w[png jpeg jpg gif svg txt js css zip gz]
  starting_uri = URI.parse(starting_at)
  seen_pages = Set.new                      # Keep track of what we've seen
  counter = 0

  crawl_page = ->(page_uri) do              # A re-usable mini-function
    unless seen_pages.include?(page_uri)
      seen_pages << page_uri                # Record that we've seen this
      begin
        doc = Nokogiri.HTML(open(page_uri)) # Get the page
        
        if doc.xpath("//meta[@name='twitter:app:name:iphone']/@content").first.to_s == "Medium"
          counter = counter+1
          puts counter.to_s

          each_page.call(doc,page_uri)        # Yield page and URI to the block

          # Find all the links on the page
          selector = "//a[starts-with(@href, \"https://\")]/@href"
          hrefs = doc.xpath selector

          # Make these URIs, throwing out problem ones like mailto:
          uris = hrefs.map{ |href| URI.join( page_uri, href ) rescue nil }.compact

          # Throw out links to files (this could be more efficient with regex)
          uris.reject!{ |uri| files.any?{ |ext| uri.path.end_with?(".#{ext}") } }

          # Remove #foo fragments so that sub-page links aren't differentiated
          uris.each{ |uri| uri.fragment = nil }

          # Recursively crawl the child URIs
          uris.each{ |uri| crawl_page.call(uri) }
        end

      rescue OpenURI::HTTPError # Guard against 404s
        warn "Skipping invalid link #{page_uri}"
      end
    end
  end

  crawl_page.call( starting_uri )   # Kick it all off!
end

def search_page(page_uri)
  page = Nokogiri.HTML(open(page_uri))
  if page.css('p.hero-description').to_s.downcase.include?("developer")
    puts page_uri.to_s
  end
end

crawl_site('https://medium.com/@retomeier') do |page,uri|
  # page here is a Nokogiri HTML document
  # uri is a URI instance with the address of the page
  search_page(uri)
end
