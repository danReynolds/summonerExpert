class Ban < ActiveRecord::Base
  belongs_to :summoner_performance

  validates_presence_of :champion_id, :summoner_performance_id
end
