require 'mechanize'
require 'pry'

README_FILE = './README.md'
NO_PLACE = Float::INFINITY

ELIM_URL = 'https://highloadcup.ru/ru/rating/round/4/'
FINAL_URL = 'https://highloadcup.ru/ru/rating/'

repos = {}
agent = Mechanize.new

file_content = File.open(README_FILE).read
file_table_content = file_content.match(/\|.*\|/m)[0]
file_table_lines = file_table_content.split("\n")
file_table_header = file_table_lines[0..1]
file_table_lines[2..-1].each do |line|
  _, place, url, lang, time, name, _ = line.split('|').map(&:strip)
  place = !place.empty? ? place.to_i : nil
  name = url if name.empty?
  lang = nil if lang.empty?
  time = time.to_f unless time.empty?
  repos[name] = { place: place, url: url, lang: lang, time: time, name: name }
end

page = agent.get(ELIM_URL)
user_rows = page.search('.rating table.table tbody tr')

user_rows.each do |user_row|
  columns = user_row.children
  place = columns[1].inner_text.gsub(/\s+/, ' ').strip.to_i
  next if place.zero?

  name = columns[7].inner_text.gsub(/\s+/, ' ').strip
  lang = ''
  m = name.match(/^(?<name>.*) \((?<lang>.*)\)$/)
  if m
    name = m[:name]
    lang = m[:lang]
  end
  time = columns[9].inner_text.gsub(/\s+/, ' ').strip.to_f
  
  repo = repos[name]

  next unless repo

  repo[:time] = time
  repo[:place] = place
  repo[:lang] ||= lang
end

page = agent.get(FINAL_URL)
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
new_table_rating = repos.values.sort_by { |repo| repo[:place] || NO_PLACE }.map do |repo|
  repo[:name] = nil if repo[:name].start_with? 'http'
  ([nil] + fields.map { |f| repo[f] } + [nil]).join(' | ').strip
end
new_file_table_content = (file_table_header+new_table_rating).join("\n")
puts new_file_table_content

file_content.gsub!(file_table_content, new_file_table_content)
File.open(README_FILE, 'w') { |f| f.write file_content }
