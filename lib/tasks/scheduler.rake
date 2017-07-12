require "#{Rails.root}/lib/external_api.rb"
require "#{Rails.root}/lib/riot_api.rb"
require "#{Rails.root}/lib/champion_gg_api.rb"
include RiotApi
include ActionView::Helpers::SanitizeHelper

namespace :champion_gg do
  task all: [:cache_champion_performance]

  # Cache how a champion does in matchups against other champs in that role
  def cache_champion_matchups(matchup_data, elo)
    matchup_data.to_a.each do |matchup_role, matchups|
      matchups.each do |matchup|
        matchup_key = [matchup['champ1_id'], matchup['champ2_id']].sort.join('-')
        unless Rails.cache.exist?({ matchup: matchup_key, matchup_role: matchup_role })
          Rails.cache.write({ matchup: matchup_key, matchup_role: matchup_role, elo: elo }, matchup)
        end
      end
    end
  end

  # Cache the ranking lists for champion performance on metrics like KDA in that role
  def cache_champion_rankings(champion_rankings, elo)
    champion_rankings.each do |role, position_names|
      position_names.each do |position_name, champion_positions|
        ranked_champion_ids = champion_positions.sort_by do |champion_position|
          champion_position[:position]
        end.map do |champion_position|
          champion_position[:id]
        end
        Rails.cache.write({ elo: elo, position: position_name, role: role }, ranked_champion_ids)
      end
    end
  end

  desc 'Cache champion role and matchup performance'
  task cache_champion_performance: :environment do
    puts 'Fetching champion data from Champion.gg'

    # Arbitrarily high enough number used for variable combinations of champions x roles
    champion_roles_limit = 10000

    ChampionGGApi::ELOS.values.each do |elo|
      puts "Fetching Champion data for #{elo}"
      champion_rankings = {}
      champion_roles = ChampionGGApi::get_champion_roles(limit: champion_roles_limit, skip: 0, elo: elo)

      champion_roles.each do |champion_role|
        id = champion_role['championId']
        role = champion_role['role']

        # Add champion rankings in different positions (metrics) to the ranking lists
        champion_role['positions'].slice(*ChampionGGApi::POSITIONS).to_a.each do |position_name, position|
          champion_rankings[role] ||= {}
          champion_rankings[role][position_name] ||= []
          champion_rankings[role][position_name] << { position: position, id: id }
        end

        cache_champion_matchups(champion_role.delete('matchups'), elo)

        # Cache how that champion does in that role overall
        role_data = champion_role
        Rails.cache.write({ id: id, role: role, elo: elo }, role_data)
      end
      cache_champion_rankings(champion_rankings, elo)
    end

    puts 'Cached champion data from Champion.gg'
  end
end


namespace :riot do
  task all: [:cache_champions, :cache_items]

  def remove_tags(description)
    prepared_text = description.split("<br>")
      .reject { |effect| effect.blank? }.join("\n")
    strip_tags(prepared_text)
  end

  desc 'Cache items'
  task cache_items: :environment do
    puts 'Fetching item data from Riot'

    RiotApi::RiotApi.get_items.each do |id, item_data|
      next unless item_data['name'] && item_data['description']
      item_data['description'] = remove_tags(item_data[:description])
      Rails.cache.write({ items: id }, item_data)
      Rails.cache.write({ item_id_by_key: item_data['name'] }, id)
    end

    puts 'Fetched item data'
  end

  desc 'Cache champions'
  task cache_champions: :environment do
    puts 'Fetching champion data from Riot'

    RiotApi::RiotApi.get_champions.each do |key, champion_data|
      id = champion_data['id']
      champion_data['blurb'] = remove_tags(champion_data['blurb'])

      Rails.cache.write({ champions: id }, champion_data)
      Rails.cache.write({ champion_id_by_key: key }, id)
    end

    puts 'Cached champions from Riot'
  end
end
