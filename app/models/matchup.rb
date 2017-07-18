class Matchup
  include CollectionHelper
  include ActiveModel::Validations

  CHAMPIONS = Rails.cache.read(:champions)

  validates :elo, presence: true
  validates :role1, presence: true
  validates :name1, presence: true, inclusion: CHAMPIONS.values
  validates :name2, presence: true, inclusion: CHAMPIONS.values
  validate :matchup_validator

  attr_accessor :elo, :role1, :role2, :name1, :name2, :matchup_role

  def initialize(**args)
    args[:name1] = CollectionHelper::match_collection(args[:name1], CHAMPIONS.values)
    args[:name2] = CollectionHelper::match_collection(args[:name2], CHAMPIONS.values)

    args.each do |key, value|
      instance_variable_set("@#{key}", value)
    end

    synergy = ChampionGGApi::MATCHUP_ROLES[:SYNERGY]
    adc = ChampionGGApi::MATCHUP_ROLES[:ADC]
    support = ChampionGGApi::MATCHUP_ROLES[:SUPPORT]
    # Prioritize the synergy role if two are specified.
    @matchup_role = if role1 == synergy || role2 == synergy
      synergy
    # The ADCSUPPORT matchup allow for dual role inquiries. The single
    # role defining these cases must be assigned from these two roles
    elsif role1 == adc && role2 == support || role1 == support && role2 == adc
      ChampionGGApi::MATCHUP_ROLES[:ADCSUPPORT]
    else
      role1
    end

    if matchups = Rails.cache.read(matchups: { name: @name1, role: @matchup_role, elo: @elo })
      @matchup = matchups[@name2]
    end
  end

  def position(position_name, champion_name)
    @matchup[champion_name][position_name]
  end

  def error_message
    errors.messages.map do |key, value|
      "#{key} #{value.first}"
    end.en.conjunction(article: false)
  end

  private

  def matchup_validator
    if @matchup.nil?
      errors.add(:Matchup, "could not be found for the given champions in the provided role and elo.")
    end
  end
end
