# coding: utf-8
require 'erb'
require 'csv'
require 'bundler'
Bundler.require


def get(range_start, range_end)
  m = Mechanize.new

  m.get "http://atnd.org/events/33746"
  entries = m.page.search('#post-body table tr').select{|e|
    e.at('td:nth-of-type(4) a')
  }.reject{|e|
    day = e.at('td').inner_text.to_i
    day < range_start || day > range_end
  }

  puts "There are #{entries.size} entries."

  # Get hatebu counts
  entries.map{|e|
    e.at('td:nth-of-type(4) a')
  }.with_progress('Detect redirect url').map{|a|
    url = a.attr 'href'
    origin_url = url
    if url.match /http:\/\/d\.hatena\.ne\.jp/
      m.get url
      url = m.page.uri.to_s
      sleep 0.5
    end
    (@url_map ||= {})[origin_url] = url
    ERB::Util.url_encode url
  }.each_slice(50).map{|urls|
    urls.join '&url='
  }.with_progress('Fetch hatebu count') do |query|
    m.get "http://api.b.st-hatena.com/entry.counts?url=#{query}"
    (@hatebu_counts ||= {}).merge! JSON.parse m.page.body
    sleep 0.5
  end

  # Create list
  entries.with_progress('Create entry list') do |entry|
    a = entry.at('td:nth-of-type(4) a')
    title = a.inner_text
    url = a.attr 'href'
    author = entry.at('td:nth-of-type(3)').inner_text
    (@rows ||= []) << [@hatebu_counts[@url_map[url]], author, title, url]
  end

  CSV.open('./export.csv', 'wb') do |csv|
    @rows.sort_by{|row|row[0]}.reverse.with_progress('Writing to csv') do |row|
      csv << row
    end
  end
end

class Console < Thor

  desc "fetch", "fetch hatebu count"
  option :start, type: :numeric, default: 1, aliases: :s
  option :end, type: :numeric, default: 365, aliases: :e
  def fetch
    puts "fetch day #{options[:start]} to day #{options[:end]} entries"
    get options[:start], options[:end]
  end

end

Console.start ARGV
