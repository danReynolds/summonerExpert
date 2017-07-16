class RolePerformance
  include ActiveModel::Validations

  validates :elo, presence: true
  validates :role, presence: true
  validates :name, presence: true
  validate :role_performance

  attr_accessor :elo, :role, :name

  # Accessors coming directly from the data object
  RELAY_ACCESSORS = [
    :winRate, :kills, :totalDamageTaken, :wardsKilled, :averageGames,
    :largestKillingSpree, :assists, :playRate, :gamesPlayed, :percentRolePlayed,
    :goldEarned, :deaths, :wardPlaced, :banRate, :minionsKilled
  ].freeze
  RELAY_ACCESSORS.each do |accessor|
    attr_accessor accessor
  end

  def initialize(**args)
    # If a role is not specified, determine if they only have one role and use
    # that one
    if args[:role].blank?
      role_performances = ChampionGGApi::ROLES.values.map do |role|
        { role: role, role_performance: Rails.cache.read(args.merge(role: role)) }
      end.reject { |role_entry| role_entry[:role_performance].nil? }

      if role_performances.length == 1
        role_entry = role_performances.first
        @role_performance = role_entry[:role_performance]
        args[:role] = role_entry[:role]
      end
    else
      @role_performance = Rails.cache.read(args)
    end

    args.each do |key, value|
      instance_variable_set("@#{key}", value)
    end

    if @role_performance
      RELAY_ACCESSORS.each do |accessor|
        instance_variable_set("@#{accessor}", @role_performance[accessor.to_s])
      end
    end
  end

  def ability_order(metric)
    @role_performance['hashes']['skillorderhash'][metric]['hash']
      .split('-')[1..-1].join(', ')
  end

  def position(position_name)
    {
      position: @role_performance['positions'][position_name.to_s],
      total_positions: @role_performance['positions']['totalPositions']
    }
  end

  def kda
    {
      kills: @kills,
      deaths: @deaths,
      assists: @assists
    }
  end

  def error_message
    errors.messages.map do |key, value|
      "#{key} #{value.first}"
    end.en.conjunction(article: false)
  end

  private

  private

  def role_performance
    if @role_performance.nil?
      errors.add(:Performance, "could not be found for the given champion in the provided role and elo.")
    end
  end
end
