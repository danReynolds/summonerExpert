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

  def champion_performance_ranking
    ids_to_names = Cache.get_collection(:champions)
    metric, position_details, role = summoner_params.slice(:metric, :position_details, :role).values.map(&:to_sym)
    filter = {}

    sort_type = if metric.present?
      metric
    elsif position_details.present?
      position_details
    else
      :winrate
    end

    if role.present?
      filter[:role] = role
      role_type = :role_specified
    else
      role_type = :no_role_specified
    end

    performance_filter = Filterable.new({
      collection: @summoner.summoner_performances.where(filter).group_by(&:champion_id),
      sort_method: performance_ranking_sort(sort_type),
      # The default sort order is best = lowest values
      reverse: true
    }.merge(summoner_params.slice(:list_order, :list_size, :list_position)))

    filtered_rankings = performance_filter.filter
    filter_types = performance_filter.filter_types
    filter_args = ApiResponse.filter_args(performance_filter)
    champions = filtered_rankings.map { |performance_data| ids_to_names[performance_data.first] }

    args = {
      position: RiotApi::POSITION_DETAILS[sort_type] || RiotApi::POSITION_METRICS[sort_type],
      champions: champions.en.conjunction(article: false),
      name: @summoner.name,
      role: ChampionGGApi::ROLES[role.to_sym].try(:humanize),
      real_size_champion_conjugation: 'champion'.en.pluralize(performance_filter.real_size)
    }.merge(filter_args)

    namespace = dig_set(
      :summoners,
      :champion_performance_ranking,
      *filter_types.values,
      role_type
    )

    render json: {
      speech: ApiResponse.get_response(namespace, args)
    }
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

  def performance_ranking_sort(sort_type)
    case sort_type
    when :count
      ->(performance_data) do
        _, performances = performance_data
        performances.count
      end
    when :KDA
      ->(performance_data) do
        _, performances = performance_data
        performances.map { |performance| performance.kda }.sum / performances.count
      end
    when :winrate
      ->(performance_data) do
        _, performances = performance_data
        performances.select { |performance| performance.victorious? }.count / performances.count.to_f
      end
    else
      ->(performance_data) do
        _, performances = performance_data
        performances.map { |performance| performance.send(sort_type) }
         .sum / performances.count.to_f
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

    if total_performances.zero?
      role_type = role ? :role_specified : :no_role_specified
      return render json: {
        speech: ApiResponse.get_response(
          dig_set(:errors, :champion_performance_summary, :does_not_play, role_type),
          args.merge({ role: role && ChampionGGApi::ROLES[role.to_sym].humanize })
        ),
      }
    end

    args[:total_performances] = "#{total_performances.to_i.en.numwords} #{'time'.pluralize(total_performances)}"
    aggregate_performance = @summoner.aggregate_performance(filter, metrics)
    role ||= aggregate_performance[:role].first if aggregate_performance[:role].uniq.length == 1

    if role
      args[:role] = ChampionGGApi::ROLES[role.to_sym].humanize
    else
      args[:roles] = aggregate_performance[:role].map do |aggregate_role|
        ChampionGGApi::ROLES[aggregate_role.to_sym].humanize
      end.en.conjunction(article: false)
      return render json: {
        speech: ApiResponse.get_response({ errors: { champion_performance_summary: :multiple_roles } }, args)
      }
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

    render json: {
      speech: ApiResponse.get_response({ summoners: "champion_performance_#{type}" }, args)
    }
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
