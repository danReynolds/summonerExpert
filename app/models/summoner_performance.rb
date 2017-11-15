class SummonerPerformance < ActiveRecord::Base
  belongs_to :team
  belongs_to :summoner
  belongs_to :match
  has_one :ban

  validates_presence_of :team_id, :summoner_id, :match_id, :participant_id,
    :champion_id, :spell1_id, :spell2_id, :kills, :deaths, :assists, :role,
    :largest_killing_spree, :total_killing_sprees, :double_kills, :triple_kills,
    :quadra_kills, :penta_kills, :total_damage_dealt, :magic_damage_dealt,
    :physical_damage_dealt, :true_damage_dealt, :largest_critical_strike,
    :total_damage_dealt_to_champions, :magic_damage_dealt_to_champions,
    :physical_damage_dealt_to_champions, :true_damage_dealt_to_champions,
    :total_healing_done, :vision_score, :cc_score, :gold_earned, :turrets_killed,
    :inhibitors_killed, :total_minions_killed, :vision_wards_bought,
    :sight_wards_bought, :wards_placed, :wards_killed, :neutral_minions_killed,
    :neutral_minions_killed_team_jungle, :neutral_minions_killed_enemy_jungle

  def kda
    (kills + assists) / deaths.to_f
  end

  def victorious?
    team == match.winning_team
  end

  def opponent
    match.summoner_performances.find do |performance|
      performance.role == role && performance != self
    end
  end
end
