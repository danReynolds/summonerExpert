class Summoner < ActiveRecord::Base
  include RiotApi

  validate :matchup_validator

  def queue(queue_name)
    queue_data = RiotApi.get_summoner_queues(
      id: summoner_id, region: region
    )[queue_name]
    RankedQueue.new(queue_data)
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
