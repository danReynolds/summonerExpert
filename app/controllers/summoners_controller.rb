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

  def champion_performance_position
    champion_performance_request(:position, [summoner_params[:position_details].to_sym, :role])
  end

  def champion_performance_summary
    champion_performance_request(:summary, [:kills, :deaths, :assists, :role])
  end

  def champion_performance_request(type, metrics)
    champion = Champion.new(name: summoner_params[:champion])
    args = { name: @summoner.name, champion: champion.name }
    role = summoner_params[:role]
    filter = { champion_id: champion.id }
    filter.merge!({ role: role }) if role.present?

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

    total_performance_text = "#{total_performances.to_i.en.numwords} #{'time'.pluralize(total_performances)}"
    aggregate_performance = @summoner.aggregate_performance(filter, metrics)
    role = aggregate_performance[:role].first if aggregate_performance[:role].uniq.length == 1

    unless role
      args.merge!({
        roles: aggregate_performance[:role].map do |aggregate_role|
          ChampionGGApi::ROLES[aggregate_role.to_sym].humanize
        end.en.conjunction(article: false),
        total_performances: total_performance_text
      })
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

    args.merge!({
      role: ChampionGGApi::ROLES[role.to_sym].humanize,
      total_performances: total_performance_text
    })

    render json: {
      speech: ApiResponse.get_response({ summoners: "champion_performance_#{type}" }, args)
    }
  end

  private

  def summoner_params
    params.require(:result).require(:parameters).permit(
      :name, :region, :champion, :queue, :role, :position_details
    )
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
