# Base class for models that need to establish a matchup role such as
# Matchup for named champion matchups and Matchup Ranking for rankings against a named
# champion.
class MatchupRole
  include CollectionHelper
  include ActiveModel::Validations
  CHAMPIONS = Rails.cache.read(:champions)

  attr_accessor :matchup_role, :role1, :role2, :elo

  validates :elo, presence: true

  protected

  def determine_matchup_role
    synergy = ChampionGGApi::MATCHUP_ROLES[:SYNERGY]
    adc = ChampionGGApi::MATCHUP_ROLES[:DUO_CARRY]
    support = ChampionGGApi::MATCHUP_ROLES[:DUO_SUPPORT]

    if @role1 == synergy || @role2 == synergy
      synergy
    elsif @role1 == adc && @role2 == support || @role1 == support && @role2 == adc
      ChampionGGApi::MATCHUP_ROLES[:ADCSUPPORT]
    else
      @role1
    end
  end
end
