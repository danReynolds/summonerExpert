class RolePerformance
  include ActiveModel::Validations

  ACCESSORS = [
    :elo, :role, :name
  ].freeze
  ACCESSORS.each do |accessor|
    attr_accessor accessor
  end

  def initialize(**args)
    if @data = Rails.cache.read(args)
      args.each do |key, value|
        instance_variable_set("@#{key}", value)
      end
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
