class RolePerformance
  include ActiveModel::Validations

  ACCESSORS = [
    :elo, :role, :name
  ].freeze
  ACCESSORS.each do |accessor|
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
        @data = role_entry[:role_performance]
        args[:role] = role_entry[:role]
      end
    else
      @data = Rails.cache.read(args)
    end

    args.each do |key, value|
      instance_variable_set("@#{key}", value)
    end
  end

  def ability_order(metric)
    @data['hashes']['skillorderhash'][metric]['hash']
      .split('-')[1..-1].join(', ')
  end

  def valid?
    @data.present?
  end
end
