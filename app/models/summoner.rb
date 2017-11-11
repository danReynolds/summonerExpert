class Summoner < ActiveRecord::Base
  has_many :summoner_performances
  has_many :matches, through: :summoner_performances
  include RiotApi

  validate :matchup_validator

  def queue(queue_name)
    queue_data = RiotApi.get_summoner_queues(
      id: summoner_id, region: region
    )[queue_name]
    RankedQueue.new(queue_data)
  end

  def aggregate_performance(filter, *metrics)
    summoner_performances.where(filter).inject({}) do |acc, performance|
      acc.tap do
        metrics.each do |metric|
          acc[metric] ||= []
          acc[metric] << performance.send(metric)
        end
      end
    end
  end

  def winrate(filter)
    performances = summoner_performances.where(filter)
    wins = performances.select { |performance| performance.match.winning_team == performance.team }
    (wins.count / performances.count.to_f * 100).round(2)
  end

  def error_message
    errors.messages.values.map(&:first).en.conjunction(article: false)
  end

  private

  def matchup_validator
    if @queue && @queue.invalid?
      errors[:base] << ApiResponse.get_response(
        { errors: { summoner: :not_active } },
        { name: @name, queue: RankedQueue::QUEUES[@queue_name.to_sym] }
      )
    end
  end
end
