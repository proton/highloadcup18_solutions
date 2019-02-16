require 'mechanize'
require 'pry'

README_FILE = './README.md'
NO_TIME = Float::INFINITY
URL = 'https://highloadcup.ru/ru/rating/'

repos = {}
agent = Mechanize.new

file_content = File.open(README_FILE).read
file_table_content = file_content.match(/\|.*\|/m)[0]
file_table_lines = file_table_content.split("\n")
file_table_header = file_table_lines[0..1]
file_table_lines[2..-1].each do |line|
  _, place, url, lang, time, name, _ = line.split('|').map(&:strip)
  place = place.to_i
  name = url if name.empty?
  lang = nil if lang.blank?
  time = time.to_f
  time = Float::INFINITY if time.zero?
  repos[name] = { place: place, url: url, lang: lang, time: time.to_f, name: name }
end

page = agent.get(URL)
user_rows = page.search('.rating-table .rating-users-col .rating-table-row')
time_rows = page.search('.rating-table .rating-result-col .rating-table-row')

user_rows.each_with_index do |user_row, i|
  time_row = time_rows[i]

  place = user_row.search('.rating-place-cell').first.inner_text.gsub(/\s+/, ' ').strip.to_i
  next if place.zero?

  name = user_row.search('.rating-user-cell').first.inner_text.gsub(/\s+/, ' ').strip
  lang = user_row.search('.rating-stack-cell').first.inner_text.gsub(/\s+/, ' ').strip
  time = time_row.inner_text.gsub(/\s+/, ' ').strip.to_f
  repo = repos[name]

  next unless repo

  repo[:time] = time
  repo[:place] = place
  repo[:lang] ||= lang
end

fields = %i(place url lang time name)
new_table_rating = repos.values.sort_by { |repo| [repo[:place], repo[:name]] }.map do |repo|
  repo[:name] = nil if repo[:name].start_with? 'http'
  repo[:time] = nil if repo[:time].infinite?
  time = repo[:time].to_f
  # repo[:time] = time.round(2) if time.to_i.to_s.size > 4
  ([nil] + fields.map { |f| repo[f] } + [nil]).join(' | ').strip
end
new_file_table_content = (file_table_header+new_table_rating).join("\n")
puts new_file_table_content

file_content.gsub!(file_table_content, new_file_table_content)
# File.open(README_FILE, 'w') { |f| f.write file_content }
