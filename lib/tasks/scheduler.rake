require "#{Rails.root}/lib/external_api.rb"
require "#{Rails.root}/lib/riot_api.rb"
require "#{Rails.root}/lib/champion_gg_api.rb"
include RiotApi
include ActionView::Helpers::SanitizeHelper

namespace :champion_gg do
  task all: [:cache_champion_performance]

  # Cache how a champion does in matchups against other champs in that role
  def cache_champion_matchups(name, id, elo, matchup_data)
    matchup_data.to_a.each do |matchup_role, matchups|
      champion_matchups = {}

      matchups.each do |matchup|
        if id == matchup['champ1_id']
          other_id = matchup['champ2_id']
          champion_matchups[other_id] = {}
          champion_matchups[other_id][id] = matchup['champ1']
          champion_matchups[other_id][other_id] = matchup['champ2']
        else
          other_id = matchup['champ1_id']
          champion_matchups[other_id] = {}
          champion_matchups[other_id][id] = matchup['champ2']
          champion_matchups[other_id][other_id] = matchup['champ1']
        end
      end
      Rails.cache.write({ champion: name, role: matchup_role, elo: elo }, champion_matchups)
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
        Rails.cache.write(
          {
            elo: elo,
            position: position_name,
            role: ChampionGGApi::ROLES[role.to_sym]
          },
          ranked_champion_ids
        )
      end
    end
  end

  desc 'Cache champion role and matchup performance'
  task cache_champion_performance: :environment do
    puts 'Fetching champion data from Champion.gg'

    # Arbitrarily high enough number used for variable combinations of champions x roles
    champion_roles_limit = 10000

    champion_ids_to_names = Rails.cache.read(:champions)

    ChampionGGApi::ELOS.to_a.each do |elo_key, elo_name|
      puts "Fetching Champion data for #{elo_key}"
      champion_rankings = {}
      champion_roles = ChampionGGApi::get_champion_roles(limit: champion_roles_limit, skip: 0, elo: elo_name)

      champion_roles.each do |champion_role|
        id = champion_role['championId']
        name = champion_ids_to_names[id]
        role = champion_role['role']

        # Add champion rankings in different positions (metrics) to the ranking lists
        champion_role['positions'].slice(*ChampionGGApi::POSITIONS).to_a.each do |position_name, position|
          champion_rankings[role] ||= {}
          champion_rankings[role][position_name] ||= []
          champion_rankings[role][position_name] << { position: position, id: id }
        end
        cache_champion_matchups(name, id, elo_key, champion_role.delete('matchups'))

        # Cache how that champion does in that role overall
        role_data = champion_role
        Rails.cache.write({ name: name, role: ChampionGGApi::ROLES[role.to_sym], elo: elo_key }, role_data)
      end
      cache_champion_rankings(champion_rankings, elo_key)
    end

    puts 'Cached champion data from Champion.gg'
  end
end


namespace :riot do
  task all: [:cache_champions, :cache_items]

  def remove_tags(description)
    prepared_text = description.split("<br>")
      .reject { |effect| effect.blank? }.join("")
    strip_tags(prepared_text)
  end

  def cache_collection(key, collection)
    ids_to_names = collection.inject({}) do |acc, collection_entry|
      acc.tap do
        acc[collection_entry['id']] = collection_entry['name']
      end
    end

    Rails.cache.write(key, ids_to_names)
  end

  desc 'Cache items'
  task cache_items: :environment do
    puts 'Fetching item data from Riot'

    items = RiotApi::RiotApi.get_items.values
    cache_collection(:items, items)

    items.each do |item_data|
      next unless item_data['name'] && item_data['description']
      item_data['description'] = remove_tags(item_data[:description])
      Rails.cache.write({ item: item_data['name'] }, item_data)
    end

    puts 'Cached item data from Riot'
  end

  desc 'Cache champions'
  task cache_champions: :environment do
    puts 'Fetching champion data from Riot'

    champions = RiotApi::RiotApi.get_champions.values
    cache_collection(:champions, champions)

    champions.each do |champion_data|
      id = champion_data['id']
      champion_data['blurb'] = remove_tags(champion_data['blurb'])
      champion_data['lore'] = remove_tags(champion_data['lore'])
      Rails.cache.write({ champion: champion_data['name'] }, champion_data)
    end

    puts 'Cached champion data from Riot'
  end
end
