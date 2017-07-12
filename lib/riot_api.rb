require './lib/matcher.rb'

module RiotApi
  class RiotApi < ExternalApi
    include Matcher

    @api_key = ENV['RIOT_API_KEY']
    @api = load_api('riot_api')

    # Default tags to use for requesting champions
    DEFAULT_TAGS = [:allytips, :blurb, :enemytips, :info, :spells, :stats, :tags, :lore]

    # Constants related to the Riot Api
    TOP = 'Top'.freeze
    JUNGLE = 'Jungle'.freeze
    SUPPORT = 'Support'.freeze
    ADC = 'ADC'.freeze
    MIDDLE = 'Middle'.freeze
    ROLES = [TOP, JUNGLE, SUPPORT, ADC, MIDDLE]
    
    STATS = {
      armor: 'armor',
      attackdamage: 'attack damage',
      attackrange: 'attack range',
      crit: 'critical chance',
      hp: 'health',
      hpregen: 'health regeneration',
      movespeed: 'movement speed',
      mp: 'mana',
      mpregen: 'mana regeneration',
      spellblock: 'magic resist'
    }.freeze

    class << self
      def get_champions(**args)
        args[:tags] ||= DEFAULT_TAGS.map do |tag|
          "&tags=#{tag}"
        end.join('')

        url = replace_url(@api[:champions], args)
        fetch_response(url)
      end

      def get_items
        fetch_response(@api[:items])
      end

      def get_summoner_champions(args)
        url = "#{replace_url(@api[:summoner][:champions], args)}?season=#{@api[:season]}"
        fetch_response(url)[:champions].reject { |champ| champ[:id].zero? }
      end

      def get_summoner_stats(args)
        url = replace_url(@api[:summoner][:ranked], args)
        id = args[:id].to_s

        return unless stats = fetch_response(url)

        stats[id].map do |division|
          division[:entries].detect do |entry|
            entry[:playerOrTeamId] == id
          end.merge(
            queue: RankedMode.new(mode: division[:queue].to_sym).mode,
            tier: division[:tier].downcase.capitalize
          )
        end
      end

      def get_summoner_id(args)
        name = URI.encode(args[:name])
        url = "#{replace_url(@api[:summoner][:id], args)}/#{name}"
        return unless response = fetch_response(url)
        response.values.first[:id].to_i
      end
    end
  end
end
