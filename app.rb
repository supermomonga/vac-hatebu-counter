# coding: utf-8
require 'erb'
require 'csv'
require 'bundler'
Bundler.require

m = Mechanize.new

m.get "http://atnd.org/events/33746"
entries = m.page.search('#post-body table tr').select{|e|e.at('td:nth-of-type(4) a')}

puts "There are #{entries.size} entries."

# Get hatebu counts
entries.map{|e|
  e.at('td:nth-of-type(4) a')
}.map{|a|
  ERB::Util.url_encode a.attr 'href'
}.each_slice(50).map{|urls|
  urls.join '&url='
}.with_progress('Fetch hatebu count') do |query|
  m.get "http://api.b.st-hatena.com/entry.counts?url=#{query}"
  (@hatebu_counts ||= {}).merge! JSON.parse m.page.body
  # sleep 0.5
end

# Create list
entries.with_progress('Create entry list') do |entry|
  a = entry.at('td:nth-of-type(4) a')
  title = a.inner_text
  url = a.attr 'href'
  author = entry.at('td:nth-of-type(3)').inner_text
  (@rows ||= []) << [@hatebu_counts[url], author, title, url]
end

CSV.open('./export.csv', 'wb') do |csv|
  @rows.sort_by{|row|-row[0]}.with_progress('Writing to csv') do |row|
    csv << row
  end
end


