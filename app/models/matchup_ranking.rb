class MatchupRanking < MatchupRole
  validates :name, presence: true, inclusion: { in: CHAMPIONS.values, allow_blank: true }
  validate :matchups_validator

  attr_accessor :name, :matchups, :named_role, :unnamed_role

  def initialize(**args)
    args[:name] = CollectionHelper::match_collection(args[:name], CHAMPIONS.values)

    args.each do |key, value|
      instance_variable_set("@#{key}", value)
    end

    @matchups = if @matchup_role = determine_matchup_role
      Rails.cache.read(matchups: { name: @name, role: @matchup_role, elo: @elo })
    else
      all_matchups_by_role = find_matchups_for_roles
      all_matchups_by_role.first if all_matchups_by_role.length == 1
    end

    if @matchups
      # Use a single matchup to determine the named champion's role and the
      # unnamed champion's role.
      matchup = @matchups.first
      other_name, matchup_data = matchup
      @named_role = ChampionGGApi::ROLES[matchup_data[@name]['role'].to_sym]
      @unnamed_role = ChampionGGApi::ROLES[matchup_data[other_name]['role'].to_sym]
    end
  end

  def error_message
    errors.messages.values.map(&:first).en.conjunction(article: false)
  end

  private

  # Find all shared roles between the champions and return the shared roles
  def find_matchups_for_roles
    roles = if @role2.present?
      case @role2
      when ChampionGGApi::ROLES[:DUO_CARRY]
        ChampionGGApi::MATCHUP_ROLES.slice(:DUO_CARRY, :ADCSUPPORT).values
      when ChampionGGApi::ROLES[:DUO_SUPPORT]
        ChampionGGApi::MATCHUP_ROLES.slice(:DUO_SUPPORT, :ADCSUPPORT).values
      else
        [@role2]
      end
    else
      ChampionGGApi::MATCHUP_ROLES.values
    end

    roles.inject([]) do |shared_matchups, matchup_role|
      matchups = Rails.cache.read(
        matchups: { name: @name, role: matchup_role, elo: @elo }
      )
      shared_matchups.tap { shared_matchups << matchups if matchups }
    end
  end

  def matchups_validator
    if errors.messages.empty? && @matchups.nil?
      args = {
        name: @name,
        elo: @elo.humanize,
        named_role: @role1.humanize,
        unnamed_role: @role2.humanize,
        matchup_role: @matchup_role
      }

      matchups = find_matchups_for_roles

      if @role1.present? && @role2.present?
        errors[:base] << ApiResponse.get_response({ errors: { matchup_ranking: { duo_roles: :empty_matchup_rankings } } }, args)
      elsif @role1.present?
        if matchups.length > 1
          errors[:base] << ApiResponse.get_response({ errors: { matchup_ranking: { named_role: :multiple_matchup_rankings } } }, args)
        else
          errors[:base] << ApiResponse.get_response({ errors: { matchup_ranking: { named_role: :empty_matchup_rankings } } }, args)
        end
      elsif @role2.present?
        if matchups.length > 1
          errors[:base] << ApiResponse.get_response({ errors: { matchup_ranking: { unnamed_role: :multiple_matchup_rankings } } }, args)
        else
          errors[:base] << ApiResponse.get_response({ errors: { matchup_ranking: { unnamed_role: :empty_matchup_rankings } } }, args)
        end
      elsif matchups.length > 1
        errors[:base] << ApiResponse.get_response({ errors: { matchup_ranking: { empty_roles: :multiple_matchup_rankings } } }, args)
      else
        errors[:base] << ApiResponse.get_response({ errors: { matchup_ranking: { empty_roles: :empty_matchup_rankings } } }, args)
      end
    end
  end
end
