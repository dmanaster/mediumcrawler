require 'set'
require 'uri'
require 'nokogiri'
require 'open-uri'

def crawl_site( starting_at, &each_page )
  files = %w[png jpeg jpg gif svg txt js css zip gz]
  starting_uri = URI.parse(starting_at)
  seen_pages = Set.new                      # Keep track of what we've seen

  crawl_page = ->(page_uri) do              # A re-usable mini-function
    unless seen_pages.include?(page_uri)
      seen_pages << page_uri                # Record that we've seen this
      begin
        doc = Nokogiri.HTML(open(page_uri)) # Get the page
        each_page.call(doc,page_uri)        # Yield page and URI to the block

        # Find all the links on the page
        hrefs = doc.css('a[href]').map{ |a| a['href'] }

        # Make these URIs, throwing out problem ones like mailto:
        uris = hrefs.map{ |href| URI.join( page_uri, href ) rescue nil }.compact

        # Pare it down to only those pages that are on the same site
        uris.select!{ |uri| uri.host == starting_uri.host }

        # Throw out links to files (this could be more efficient with regex)
        uris.reject!{ |uri| files.any?{ |ext| uri.path.end_with?(".#{ext}") } }

        # Remove #foo fragments so that sub-page links aren't differentiated
        uris.each{ |uri| uri.fragment = nil }

        # Recursively crawl the child URIs
        uris.each{ |uri| crawl_page.call(uri) }

      rescue OpenURI::HTTPError # Guard against 404s
        warn "Skipping invalid link #{page_uri}"
      end
    end
  end

  crawl_page.call( starting_uri )   # Kick it all off!
end

crawl_site('http://phrogz.net/') do |page,uri|
  # page here is a Nokogiri HTML document
  # uri is a URI instance with the address of the page
  puts uri
end
