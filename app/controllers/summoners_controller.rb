class SummonersController < ApplicationController
  include RiotApi
  include Utils
  before_action :load_summoner

  def performance_summary
    name = @summoner.name
    queue = @summoner.queue(summoner_params[:queue])

    args = {
      name: name,
      lp: queue.lp,
      rank: queue.rank,
      winrate: queue.winrate,
      hot_streak: queue.hot_streak ? 'on' : 'not on',
      elo: queue.elo.humanize,
      queue: queue.name
    }

    render json: {
      speech: ApiResponse.get_response({ summoners: :performance_summary }, args)
    }
  end

  def champion_matchup_ranking
    champion = Champion.new(name: summoner_params[:champion])
    metric, position_details, role = summoner_params.slice(
      :metric, :position_details, :role
    ).values.map(&:to_sym)
    sort_type = [metric, position_details, :winrate].find(&:present?)
    args = { name: @summoner.name, champion: champion.name }
    filter = { champion_id: champion.id }
    filter[:role] = role if role.present?
    summoner_performances = @summoner.summoner_performances.where(filter)
    total_performances = summoner_performances.count
    args[:total_performances] = "#{total_performances.to_i.en.numwords} #{'time'.pluralize(total_performances)}"
    return does_not_play_response(args, role) if summoner_performances.length.zero?

    if role.blank?
      roles = summoner_performances.map(&:role).uniq
      if roles.length == 1
        role = roles.first
      else
        return multiple_roles_response(args, roles)
      end
    end

    performance_rankings = summoner_performances.where(filter)
      .map(&:opponent).compact.group_by(&:champion_id).to_a

    matchup_filter = Filterable.new({
      collection: performance_rankings,
      sort_method: performance_ranking_sort(sort_type),
      reverse: true
    }.merge(summoner_params.slice(:list_order, :list_size, :list_position)))

    filtered_rankings = matchup_filter.filter
    filter_types = matchup_filter.filter_types
    args.merge!(ApiResponse.filter_args(matchup_filter))
    ids_to_names = Cache.get_collection(:champions)
    champions = filtered_rankings.map { |performance_data| ids_to_names[performance_data.first] }

    args.merge!({
      position: RiotApi::POSITION_DETAILS[sort_type] || RiotApi::POSITION_METRICS[sort_type],
      champions: champions.en.conjunction(article: false),
      role: ChampionGGApi::ROLES[role.to_sym].humanize,
      real_size_champion_conjugation: 'champion'.en.pluralize(matchup_filter.real_size)
    })

    namespace = dig_set(:summoners, :champion_matchup_ranking, *filter_types.values)
    render json: { speech: ApiResponse.get_response(namespace, args) }
  end

  def champion_performance_ranking
    metric, position_details, role = summoner_params.slice(
      :metric, :position_details, :role
    ).values.map(&:to_sym)
    filter = {}
    sort_type = [metric, position_details, :winrate].find(&:present?)

    role_type = if role.present?
      filter[:role] = role
      :role_specified
    else
      :no_role_specified
    end

    performance_filter = Filterable.new({
      collection: @summoner.summoner_performances.where(filter).group_by(&:champion_id).to_a,
      sort_method: performance_ranking_sort(sort_type),
      reverse: true
    }.merge(summoner_params.slice(:list_order, :list_size, :list_position)))

    filtered_rankings = performance_filter.filter
    filter_types = performance_filter.filter_types
    filter_args = ApiResponse.filter_args(performance_filter)
    ids_to_names = Cache.get_collection(:champions)
    champions = filtered_rankings.map { |performance_data| ids_to_names[performance_data.first] }

    args = {
      position: RiotApi::POSITION_DETAILS[sort_type] || RiotApi::POSITION_METRICS[sort_type],
      champions: champions.en.conjunction(article: false),
      name: @summoner.name,
      role: ChampionGGApi::ROLES[role.to_sym].try(:humanize),
      real_size_champion_conjugation: 'champion'.en.pluralize(performance_filter.real_size)
    }.merge(filter_args)

    namespace = dig_set(:summoners, :champion_performance_ranking, *filter_types.values, role_type)
    render json: { speech: ApiResponse.get_response(namespace, args) }
  end

  def champion_performance_position
    champion_performance_request(:position, [summoner_params[:position_details].to_sym, :role])
  end

  def champion_performance_summary
    champion_performance_request(:summary, [:kills, :deaths, :assists, :role])
  end

  private

  def summoner_params
    params.require(:result).require(:parameters).permit(
      :name, :region, :champion, :queue, :role, :position_details, :metric,
      :list_order, :list_size, :list_position
    )
  end

  def does_not_play_response(args, role)
    role_type = if role.present?
      args[:role] = ChampionGGApi::ROLES[role.to_sym].humanize
      :role_specified
    else
      :no_role_specified
    end

    render json: {
      speech: ApiResponse.get_response(
        dig_set(:errors, :summoner, :champion, :does_not_play, role_type),
        args
      )
    }
  end

  def multiple_roles_response(args, collection)
    args[:roles] = collection.map do |role|
      ChampionGGApi::ROLES[role.to_sym].humanize
    end.en.conjunction(article: false)
    return render json: {
      speech: ApiResponse.get_response(
        dig_set(:errors, :summoner, :champion, :multiple_roles),
        args
      )
    }
  end

  def performance_ranking_sort(sort_type)
    case sort_type
    when :count
      ->(performance_data) do
        champion_id, performances = performance_data
        [performances.count, champion_id]
      end
    when :KDA
      ->(performance_data) do
        champion_id, performances = performance_data
        [performances.map(&:kda).sum / performances.count, champion_id]
      end
    when :winrate
      ->(performance_data) do
        champion_id, performances = performance_data
        [performances.select(&:victorious?).count / performances.count.to_f, champion_id]
      end
    else
      ->(performance_data) do
        champion_id, performances = performance_data
        sort_method = performances.map { |performance| performance.send(sort_type) }
         .sum / performances.count.to_f
       [sort_method, champion_id]
      end
    end
  end

  def champion_performance_request(type, metrics)
    champion = Champion.new(name: summoner_params[:champion])
    args = { name: @summoner.name, champion: champion.name }
    role = summoner_params[:role]
    filter = { champion_id: champion.id }
    filter[:role] = role if role.present?

    champion_performances = @summoner.summoner_performances.where(filter)
    total_performances = champion_performances.size.to_f
    args[:total_performances] = "#{total_performances.to_i.en.numwords} #{'time'.pluralize(total_performances)}"

    return does_not_play_response(args, role) if total_performances.zero?

    aggregate_performance = @summoner.aggregate_performance(filter, metrics)
    role = aggregate_performance[:role].first if role.blank? && aggregate_performance[:role].uniq.length == 1

    if role.present?
      args[:role] = ChampionGGApi::ROLES[role.to_sym].humanize
    else
      return multiple_roles_response(args, aggregate_performance[:role])
    end

    if type == :summary
      metrics.reject { |metric| metric == :role }.each do |metric|
        args[metric] = (aggregate_performance[metric].sum / total_performances).round(2)
      end
      args[:winrate] = @summoner.winrate(filter)
    else
      position = metrics.first
      args[:position_name] = RiotApi::POSITION_DETAILS[position]
      args[:position_value] = (aggregate_performance[position].sum / total_performances).round(2)
    end

    render json: { speech: ApiResponse.get_response({ summoners: "champion_performance_#{type}" }, args) }
  end

  def load_summoner
    @summoner = Summoner.find_by(
      name: summoner_params[:name],
      region: summoner_params[:region]
    )

    unless @summoner.try(:valid?)
      speech = @summoner ? @summoner.error_message : ApiResponse.get_response(
        dig_set(:errors, :summoner, :not_active),
        { name: summoner_params[:name] }
      )
      render json: { speech: speech }
      return false
    end
  end
end
