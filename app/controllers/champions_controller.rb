class ChampionsController < ApplicationController
  include RiotApi
  include Sortable
  before_action :load_champion, except: [:ranking, :matchup]
  before_action :load_matchup, only: :matchup
  before_action :load_role_performance, only: [:ability_order, :build, :counters, :role_performance_summary]

  MIN_MATCHUPS = 100
  STAT_PER_LEVEL = :perlevel
  HTML_TAGS = /<("[^"]*"|'[^']*'|[^'">])*>/

  METRICS = {
    highestWinrate: 'highest win rate',
    highestCount: 'most frequent'
  }

  def ranking
    ids_to_names = Rails.cache.read(:champions)
    ranking_ids = Rails.cache.read(champion_params.slice(:position, :elo, :role).to_h)

    sortable_ranking_ids = Sortable.new({
      collection: ranking_ids
    }.merge(champion_params.slice(:list_position, :list_size, :list_order)))

    ranking_names = sortable_ranking_ids.sort.map do |ranking_id|
      ids_to_names[ranking_id]
    end

    args = {
      position: ChampionGGApi::POSITIONS[champion_params[:position].to_sym],
      role: champion_params[:role].humanize,
      elo: champion_params[:elo].humanize,
      names: ranking_names.en.conjunction(article: false),
      list_size: sortable_ranking_ids.list_size_message,
      list_position: sortable_ranking_ids.list_position_message,
      list_order: sortable_ranking_ids.list_order,
      names_conjugation: "is".en.plural_verb(sortable_ranking_ids.list_size.to_i),
      champion_conjugation: "champion".en.pluralize(sortable_ranking_ids.list_size.to_i)
    }

    render json: {
      speech: ApiResponse.get_response({ champions: :ranking }, args)
    }
  end

  def stats
    name = @champion.name
    stats = @champion.stats
    stat = champion_params[:stat]
    level = champion_params[:level].to_i
    stat_value = stats[stat]
    stat_name = RiotApi::STATS[stat.to_sym]
    level_message = ''

    if stat_modifier = stats["#{stat}#{STAT_PER_LEVEL}"]
      return render json: ask_for_level_response unless level.positive?

      level_message = " at level #{level}"
      stat_value += stat_modifier * (level - 1)
    end

    render json: {
      speech: (
        "#{name} has #{stat_value.round} #{stat_name}#{level_message}."
      )
    }
  end

  def ability_order
    args = {
      name: @champion.name,
      metric: METRICS[champion_params[:metric].to_sym],
      ability_order: @role_performance.ability_order(champion_params[:metric]),
      elo: @role_performance.elo.humanize,
      role: @role_performance.role.humanize
    }
    render json: {
      speech: ApiResponse.get_response({ champions: :ability_order }, args)
    }
  end

  def build
    build = @role_performance[:items][:highestWinPercent][:items].map do |item|
      item[:name]
    end.en.conjunction(article: false)

    render json: {
      speech: (
        "The highest win rate build for #{@champion.name} #{@role} is #{build}."
      )
    }
  end

  def matchup
    position = champion_params[:matchup_position]
    matchup_position = ChampionGGApi::MATCHUP_POSITIONS[position.to_sym]
    champ1_result = @matchup.position(position, @matchup.name1)
    champ2_result = @matchup.position(position, @matchup.name2)
    role1 = ChampionGGApi::MATCHUP_ROLES[@matchup.position('role', @matchup.name1).to_sym]
    role2 = ChampionGGApi::MATCHUP_ROLES[@matchup.position('role', @matchup.name2).to_sym]

    response_query = {}

    matchup_key = if @matchup.role1 == ChampionGGApi::MATCHUP_ROLES[:SYNERGY]
      :synergy
    elsif role1 == role2
      :single_role
    else
      :duo_role
    end

    if matchup_position == ChampionGGApi::MATCHUP_POSITIONS[:winrate]
      champ1_result *= 100
      champ2_result *= 100
      response_query[matchup_key] = :winrate
    else
      response_query[matchup_key] = :general
    end

    args = {
      position: matchup_position,
      champ1_result: champ1_result.round(2),
      champ2_result: champ2_result.round(2),
      elo: @matchup.elo.humanize,
      role1: role1.humanize,
      role2: role2.humanize,
      name1: @matchup.name1,
      name2: @matchup.name2,
      match_result: champ1_result > champ2_result ? 'higher' : 'lower'
    }

    render json: {
      speech: ApiResponse.get_response({ champions: { matchup: response_query } }, args)
    }
  end

  def counters
    matchups = @role_performance[:matchups].select do |matchup|
      matchup[:games] >= MIN_MATCHUPS
    end

    if matchups.blank?
      return render json: {
        speech: (
          "There is not enough data for #{@champion.name} in the current patch."
        )
      }
    end

    sortable_counters = Sortable.new({
      collection: matchups,
      sort_order: -> matchup { matchup[:statScore] }
    }.merge(champion_params.slice(:list_size, :list_position, :list_order)))
    champions = Rails.cache.read(:champions)

    counters = sortable_counters.sort.map do |counter|
      "#{champions[counter[:key]][:name]} at a " \
      "#{(100 - counter[:winRate]).round(2)}% win rate"
    end
    list_size_message = sortable_counters.list_size_message
    list_position_message = sortable_counters.list_position_message
    list_size = sortable_counters.list_size.to_i

    render json: {
      speech: (
        "#{insufficient_champions_message(counters.size, 'counter')}The " \
        "#{list_position_message}#{sortable_counters.list_order} " \
        "#{list_size_message}#{'counter'.en.pluralize(counters.size)} " \
        "for #{@champion.name} #{@role} #{'is'.en.plural_verb(counters.size)} " \
        "#{counters.en.conjunction(article: false)}."
      )
    }
  end

  # Provides a summary of a champion's performance in a lane
  # including factors such as KDA, overall performance ranking, percentage played in that
  # lane and more.
  def role_performance_summary
    overall_performance = @role_performance.position(:overallPerformanceScore)
    previous_overall_performance = @role_performance.position(:previousOverallPerformanceScore)
    position = overall_performance[:position]

    args = {
      elo: @role_performance.elo.humanize,
      role: @role_performance.role.humanize,
      name: @role_performance.name,
      win_rate: "#{(@role_performance.winRate * 100).round(2)}%",
      ban_rate: "#{(@role_performance.banRate * 100).round(2)}%",
      kda: @role_performance.kda.values.map { |val| val.round(2) }.join('/'),
      position: position.en.ordinal,
      total_positions: overall_performance[:total_positions],
      position_change: position - previous_overall_performance[:position] > 0 ? 'better' : 'worse'
    }

    render json: {
      speech: ApiResponse.get_response({ champions: :role_performance_summary }, args)
    }
  end

  def ability
    ability_position = champion_params[:ability_position]
    ability = @champion.ability(ability_position.to_sym)
    args = {
      position: ability_position,
      description: ability[:sanitizedDescription],
      champion_name: @champion.name,
      ability_name: ability[:name]
    }

    render json: {
      speech: ApiResponse.get_response({ champions: :ability }, args)
    }
  end

  def cooldown
    ability = champion_params[:ability].to_sym
    spell = @champion.spells[RiotApi::ABILITIES[ability]]
    rank = champion_params[:rank].split(' ').last.to_i

    render json: {
      speech: (
        "#{@champion.name}'s #{ability} ability, #{spell[:name]}, has a " \
        "cooldown of #{spell[:cooldown][rank - 1].to_i} seconds at rank #{rank}."
      )
    }
  end

  def lore
    args = { name: @champion.name, lore: @champion.lore }
    render json: {
      speech: ApiResponse.get_response({ champions: :lore }, args)
    }
  end

  def title
    args = { title: @champion.title, name: @champion.name }
    render json: {
      speech: ApiResponse.get_response({ champions: :title }, args)
    }
  end

  def ally_tips
    tip = remove_html_tags(@champion.allytips.sample.to_s)
    args = { name: @champion.name, tip: tip }

    render json: {
      speech: ApiResponse.get_response({ champions: :allytips }, args)
    }
  end

  def enemy_tips
    tip = remove_html_tags(@champion.enemytips.sample.to_s)
    args = { name: @champion.name, tip: tip }

    render json: {
      speech: ApiResponse.get_response({ champions: :enemytips }, args)
    }
  end

  private

  def remove_html_tags(speech)
    speech.gsub(HTML_TAGS, '')
  end

  def load_matchup
    @matchup = Matchup.new(
      name1: champion_params[:name1],
      name2: champion_params[:name2],
      elo: champion_params[:elo],
      role1: champion_params[:role1],
      role2: champion_params[:role2]
    )

    unless @matchup.valid?
      render json: { speech: @matchup.error_message }
      return false
    end
  end

  def load_champion
    @champion = Champion.new(name: name)

    unless @champion.valid?
      render json: { speech: @champion.error_message }
      return false
    end
  end

  def load_role_performance
    elo = champion_params[:elo]
    role = champion_params[:role]

    @role_performance = RolePerformance.new(
      elo: elo,
      role: role,
      name: @champion.name
    )

    unless @role_performance.valid?
      if role.blank? || elo.blank?
        render json: {
          speech: @role_performance.error_message
        }
      else
        args = {
          name: @champion.name,
          role: role.humanize,
          elo: elo.humanize
        }
        render json: {
          speech: ApiResponse.get_response({ champions: { errors: :does_not_play } }, args)
        }
      end
      return false
    end
  end

  def tag_message(tag, size)
    tag.blank? ? 'champion'.pluralize(size) : tag.en.downcase.pluralize(size)
  end

  def champion_params
    params.require(:result).require(:parameters).permit(
      :name, :champion1, :ability_position, :rank, :role, :list_size, :list_position,
      :list_order, :stat, :level, :tag, :elo, :metric, :position, :name1, :name2, :matchup_position, :role1, :role2
    )
  end
end
