class MatchupRanking < MatchupRole
  validates :name, presence: true, inclusion: { in: CHAMPIONS.values, allow_blank: true }
  validate :matchups_validator

  attr_accessor :name, :matchups, :named_role, :unnamed_role

  def initialize(**args)
    args[:name] = CollectionHelper::match_collection(args[:name], CHAMPIONS.values)

    args.each do |key, value|
      instance_variable_set("@#{key}", value)
    end

    @matchup_role = determine_matchup_role
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
