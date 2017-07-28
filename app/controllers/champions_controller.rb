class ChampionsController < ApplicationController
  include RiotApi
  include Sortable
  before_action :load_champion, except: [:ranking, :matchup, :matchup_ranking]
  before_action :load_matchup, only: :matchup
  before_action :load_role_performance, only: [:role_performance_summary, :build, :ability_order]
  before_action :load_matchup_ranking, only: :matchup_ranking

  def ranking
    rankings = Rails.cache.read(champion_params.slice(:position, :elo, :role).to_h)
    sortable_rankings = Sortable.new({
      collection: rankings
    }.merge(champion_params.slice(:list_position, :list_size, :list_order)))
    filtered_rankings = sortable_rankings.sort

    args = {
      position: ChampionGGApi::POSITIONS[champion_params[:position].to_sym],
      role: champion_params[:role].humanize,
      elo: champion_params[:elo].humanize,
      names: filtered_rankings.en.conjunction(article: false),
      list_size: sortable_rankings.list_size_message,
      list_position: sortable_rankings.list_position_message,
      list_order: sortable_rankings.list_order,
      names_conjugation: 'is'.en.plural_verb(sortable_rankings.list_size.to_i),
      champion_conjugation: 'champion'.en.pluralize(sortable_rankings.list_size.to_i)
    }

    render json: {
      speech: ApiResponse.get_response({ champions: :ranking }, args)
    }
  end

  def stats
    stat_key = champion_params[:stat]
    level = champion_params[:level].to_i

    args = {
      name: @champion.name,
      level: level,
      stat_name: RiotApi::STATS[stat_key.to_sym],
      stat: @champion.stat(stat_key, level).round(2)
    }

    render json: {
      speech: ApiResponse.get_response({ champions: :stats }, args)
    }
  end

  def ability_order
    args = {
      name: @champion.name,
      metric: ChampionGGApi::METRICS[champion_params[:metric].to_sym],
      ability_order: @role_performance.ability_order(champion_params[:metric]),
      elo: @role_performance.elo.humanize,
      role: @role_performance.role.humanize
    }
    render json: {
      speech: ApiResponse.get_response({ champions: :ability_order }, args)
    }
  end

  def build
    metric = champion_params[:metric]
    ids_to_names = Rails.cache.read(:items)
    item_names = @role_performance.item_ids(metric).map do |id|
      ids_to_names[id]
    end.en.conjunction(article: false)

    args = {
      elo: @role_performance.elo.humanize,
      role: @role_performance.role.humanize,
      item_names: item_names,
      name: @role_performance.name,
      metric: ChampionGGApi::METRICS[metric.to_sym]
    }

    render json: {
      speech: ApiResponse.get_response({ champions: :build }, args)
    }
  end

  def matchup
    position = champion_params[:matchup_position]
    matchup_position = ChampionGGApi::MATCHUP_POSITIONS[position.to_sym]
    champ1_result = @matchup.position(position, @matchup.name1)
    champ2_result = @matchup.position(position, @matchup.name2)
    role1 = ChampionGGApi::MATCHUP_ROLES[@matchup.position('role', @matchup.name1).to_sym]
    role2 = ChampionGGApi::MATCHUP_ROLES[@matchup.position('role', @matchup.name2).to_sym]

    matchup_key = if @matchup.matchup_role == ChampionGGApi::MATCHUP_ROLES[:SYNERGY]
      :synergy
    elsif role1 == role2
      :single_role
    else
      :duo_role
    end

    response_query = {}
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

  def matchup_ranking
    matchup_position = champion_params[:matchup_position]
    matchup_role = @matchup_ranking.matchup_role
    name = @matchup_ranking.name

    sortable_rankings = Sortable.new({
      collection: @matchup_ranking.matchups,
      # the default sort order is best = lowest
      sort_value: ->(name, matchup) { matchup[name][matchup_position] * -1 }
    }.merge(champion_params.slice(:list_position, :list_size, :list_order)))
    ranked_names = sortable_rankings.sort.map { |ranking_name| ranking_name.first.dup }


    matchup_key = if matchup_role == ChampionGGApi::MATCHUP_ROLES[:SYNERGY]
      :synergy
    elsif matchup_role == ChampionGGApi::MATCHUP_ROLES[:ADCSUPPORT]
      :duo_role
    else
      :single_role
    end

    if matchup_position == ChampionGGApi::MATCHUP_POSITIONS[:winrate]
      champ1_result *= 100
      champ2_result *= 100
    end

    args = {
      elo: @matchup_ranking.elo.humanize,
      position: ChampionGGApi::MATCHUP_POSITIONS[matchup_position.to_sym],
      unnamed_role: @matchup_ranking.unnamed_role.humanize,
      named_role: @matchup_ranking.named_role.humanize,
      name: @matchup_ranking.name,
      ranked_names: ranked_names.en.conjunction(article: false),
      list_size: sortable_rankings.list_size_message,
      list_position: sortable_rankings.list_position_message,
      list_order: sortable_rankings.list_order,
      names_conjugation: 'is'.en.plural_verb(sortable_rankings.list_size.to_i),
      champion_conjugation: 'champion'.en.pluralize(sortable_rankings.list_size.to_i)
    }
    render json: {
      speech: ApiResponse.get_response({ champions: { matchup_ranking: matchup_key } }, args)
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
    ability_position = champion_params[:ability_position].to_sym
    rank = champion_params[:rank].split(' ').last.to_i
    ability = @champion.ability(ability_position)

    args = {
      name: @champion.name,
      rank: rank,
      ability_position: ability_position,
      ability_name: ability[:name],
      ability_cooldown: ability[:cooldown][rank].to_i
    }

    render json: {
      speech: ApiResponse.get_response({ champions: :cooldown }, args)
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

  HTML_TAGS = /<("[^"]*"|'[^']*'|[^'">])*>/
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

  def load_matchup_ranking
    @matchup_ranking = MatchupRanking.new(
      name: champion_params[:name],
      elo: champion_params[:elo],
      role1: champion_params[:role1],
      role2: champion_params[:role2]
    )

    unless @matchup_ranking.valid?
      render json: { speech: @matchup_ranking.error_message }
      return false
    end
  end

  def load_champion
    @champion = Champion.new(name: champion_params[:name])

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
      render json: { speech: @role_performance.error_message }
      return false
    end
  end

  def champion_params
    params.require(:result).require(:parameters).permit(
      :name, :champion1, :ability_position, :rank, :role, :list_size, :list_position,
      :list_order, :stat, :level, :tag, :elo, :metric, :position, :name1, :name2,
      :matchup_position, :role1, :role2
    )
  end
end
