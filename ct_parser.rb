require 'open-uri'
require 'Nokogiri'

@per_event_hash = Hash.new

def parse_results(result_file)
  puts "computing file:#{result_file}"

  published_results = Nokogiri::HTML(open(result_file))

  rows = published_results.css('tr')
  #puts rows.inspect
  distance = 'N/A'
  details = rows.collect do |row|
    detail = {}
    [
      [:distance, 'td[1]/h1/font/text()'],
      [:global_rank, 'td[1]/p/font/text()'],
      [:name, 'td[2]/font/text()'],
      [:city, 'td[3]/font/text()'],
      [:bib, 'td[4]/p/font/text()'],
      [:age, 'td[5]/p/font/text()'],
      [:age_group_line, 'td[6]/p/font/text()'],
    ].each do |name, xpath|
      detail[name] = row.at_xpath(xpath).to_s.strip
      if name == :distance && !detail[name].empty?
        puts "processing distance:#{detail[name]}"
        distance = detail[name]
      end
      detail[:distance] = distance
    end
    temp_array = detail[:age_group_line].split(' ')
    detail[:age_group_rank] = temp_array[0]
    detail[:age_group] = temp_array[1].to_s << temp_array[2].to_s
    #puts "detail:#{detail}"
    detail
  end
  #puts details

  if !@per_event_hash.key?(result_file)
    @per_event_hash[result_file] = details
  end

end

def get_distance_category(distance)
  return "Short" if ["4 mi","5 mi","6 mi","7 mi","8 mi","9 mi","10 mi","10 Km"].include?(distance)
  return "Half" if ["Half Marathon","11 mi","12 mi","13 mi","14 mi"].include?(distance)
  return "Long" if ["15 mi","16 mi","17 mi","18 mi","19 mi","20 mi","21 mi","22 mi","30 Km","25 Km"].include?(distance)
  return "Marathon" if ["Marathon"].include?(distance)
  return "50k" if ["50 Km"].include?(distance)
  return "50m" if ["50 mi"].include?(distance)
  return "100m" if ["100 mi"].include?(distance)
  puts "unrecognized distance:#{distance}"
end

def get_points(rank, multiplier=1)
  return 25*multiplier if rank == '1'
  return 18*multiplier if rank == '2'
  return 15*multiplier if rank == '3'
  return 12*multiplier if rank == '4'
  return 10*multiplier if rank == '5'
  return 8*multiplier if rank == '6'
  return 6*multiplier if rank == '7'
  return 4*multiplier if rank == '8'
  return 2*multiplier if rank == '9'
  return 1*multiplier if rank == '10'
  return 0
end

def get_age_group(small_age_group)
  #sample input: ['M35-39']
  sex = small_age_group[0]
  puts "small age group: #{small_age_group}"
  return if small_age_group.empty?
  split_ages = small_age_group[1..-1].split("-")
  if split_ages[1].to_i - split_ages[0].to_i == 9
    return small_age_group
  else
    dozen_char = split_ages[0][0]
    #if dozen_char == "0"
    return "#{sex}#{dozen_char}0-#{dozen_char}9"
  end
end

def compute_results
  #read all the keys (events) and aggregate points for individuals
  per_distance_hash = Hash.new
  @per_event_hash.each do |event,results|
      results.each do |result|
        age_group = result[:age_group]
        ten_year_age_group = get_age_group(age_group)
        distance = result[:distance]
        rank = result[:age_group_rank]
        distance_category = get_distance_category(distance)
        points = get_points(rank)
        rank_points ="#{rank}:#{points}:#{age_group}"
        name = "#{result[:name]}-#{result[:age]}"

        if !per_distance_hash.key?(distance_category)
          per_distance_hash[distance_category] = Hash.new
        end
        if !per_distance_hash[distance_category].key?(ten_year_age_group)
          per_distance_hash[distance_category][ten_year_age_group] = Hash.new
        end

        if per_distance_hash[distance_category][ten_year_age_group].key?(name)
          per_distance_hash[distance_category][ten_year_age_group][name] << rank_points
        else
          per_distance_hash[distance_category][ten_year_age_group][name] = [rank_points]
        end

      end
  end

  per_distance_hash
end

def compute_totals(per_distance_hash, strict_rules=true)
  list = []
  per_distance_hash.map do |runner, results|
    points = 0
    if strict_rules && results.length >1
      #strict_rules mean at least completed 2 events
      results.each do |result|
        points += result.split(":")[1].to_i
      end

      list << [runner, points]
    end
  end
  list.sort_by { |e| -e[1]  }
end

def generate_key(event, year)
  "#{@url_root}#{event}_results_#{year}.htm"
end

@url_root = "http://www.coastaltrailruns.com/"
@year = "16"

#up to May 31st
#events = %w[sr cs_wntr gg mm cm_wntr sf100 gp ac hl cin_spr]

#most recent
events = %w[sr cs_wntr gg mm cm_wntr sf100 gp ac hl cin_spr bcf bigbasin50 cm_spr]

events.each do |event|
  parse_results(generate_key(event, @year))
end

#puts(@per_event_hash[generate_key('gg', @year)])

per_distance_hash = compute_results
puts per_distance_hash['Half']['M30-39']

#TODO: self discover the distances and categories
list = compute_totals(per_distance_hash['Half']['M30-39'])
list.each do |result|
  puts "#{result[0]}:#{result[1]}pts"
end
