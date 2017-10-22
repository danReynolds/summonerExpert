class Ban < ActiveRecord::Base
  belongs_to :match

  validates_presence_of :match_id, :champion_id, :order
end
