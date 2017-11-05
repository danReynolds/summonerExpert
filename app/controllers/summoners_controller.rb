class SummonersController < ApplicationController
  include RiotApi
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

  def champion_performance_summary
    champion = Champion.new(name: summoner_params[:champion])
    role = summoner_params[:role]

    if role.present?
      champion_performances = @summoner.summoner_performances.where(champion_id: champion.id, role: role)
      performance_type = :role_specified
    else
      champion_performances = @summoner.summoner_performances.where(champion_id: champion.id)
      performance_type = :no_role_specified
    end

    total_performances = champion_performances.size.to_f
    aggregate_performance = @summoner.aggregate_performance(
      champion, :kills, :deaths, :assists, :role
    )
    roles = if aggregate_performance[:role].uniq.length > 1
      aggregate_performance[:role]
        .map { |role| ChampionGGApi::ROLES[role.to_sym].humanize }
        .group_by(&:itself)
        .map { |role, occurences| "#{role} #{(occurences.length / total_performances * 100).round(2)}%" }
        .en.conjunction(article: false)
    else
      ChampionGGApi::ROLES[aggregate_performance[:role].first.to_sym].humanize
    end

    args = {
      name: @summoner.name,
      champion: champion.name,
      kills: aggregate_performance[:kills].sum / total_performances,
      deaths: aggregate_performance[:deaths].sum / total_performances,
      assists: aggregate_performance[:assists].sum / total_performances,
      roles: roles,
      given_role: ChampionGGApi::ROLES[role.to_sym].humanize,
      total_performances: "#{total_performances.to_i.en.numwords} #{'game'.pluralize(total_performances)}"
    }

    render json: {
      speech: ApiResponse.get_response({ summoners: { champion_performance_summary: performance_type } }, args)
    }
  end

  private

  def summoner_params
    params.require(:result).require(:parameters).permit(
      :name, :region, :champion, :queue, :role
    )
  end

  def load_summoner
    @summoner = Summoner.find_by(
      name: summoner_params[:name],
      region: summoner_params[:region]
    )

    unless @summoner.try(:valid?)
      render json: { speech: @summoner.error_message }
      return false
    end
  end
end
