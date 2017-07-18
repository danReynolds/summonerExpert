class MatchupRanking
  include CollectionHelper
  include ActiveModel::Validations

  CHAMPIONS = Rails.cache.read(:champions)

  validates :elo, presence: true
  validates :role1, presence: true
  validates :name, presence: true, inclusion: CHAMPIONS.values
  validate :matchups_validator

  attr_accessor :elo, :role1, :role2, :name, :matchups, :matchup_role, :named_role, :unnamed_role

  def initialize(**args)
    args[:name] = CollectionHelper::match_collection(args[:name], CHAMPIONS.values)

    args.each do |key, value|
      instance_variable_set("@#{key}", value)
    end

    synergy = ChampionGGApi::MATCHUP_ROLES[:SYNERGY]
    adc = ChampionGGApi::MATCHUP_ROLES[:DUO_CARRY]
    support = ChampionGGApi::MATCHUP_ROLES[:DUO_SUPPORT]
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

    if @matchups = Rails.cache.read(matchups: { name: @name, role: @matchup_role, elo: @elo })
      # Use a single matchup to determine the named champion's role and the
      # unnamed champion's role.
      matchup = @matchups.first
      other_name, matchup_data = matchup
      @named_role = ChampionGGApi::ROLES[matchup_data[@name]['role'].to_sym]
      @unnamed_role = ChampionGGApi::ROLES[matchup_data[other_name]['role'].to_sym]
    end
  end

  def error_message
    errors.messages.map do |key, value|
      "#{key} #{value.first}"
    end.en.conjunction(article: false)
  end

  private

  def matchups_validator
    if @matchups.nil? && errors.empty?
      errors.add(:Matchups, "could not be found for the given champion in the provided role and elo.")
    end
  end
end
