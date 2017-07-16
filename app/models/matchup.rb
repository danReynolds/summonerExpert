class Matchup
  include CollectionHelper
  include ActiveModel::Validations

  validates :elo, presence: true
  validates :role1, presence: true
  validates :name1, presence: true
  validates :name2, presence: true


  attr_accessor :elo, :role1, :role2, :name1, :name2

  def initialize(**args)
    ids_to_names = Rails.cache.read(:champions)
    args[:name1] = CollectionHelper::match_collection(args[:name1], ids_to_names.values)
    args[:name2] = CollectionHelper::match_collection(args[:name2], ids_to_names.values)

    args.each do |key, value|
      instance_variable_set("@#{key}", value)
    end

    # The ADCSUPPORT matchup allow for dual role inquiries. The single
    # role defining these cases must be assigned from these two roles
    role = if role1.present? && role2.present?
      ChampionGGApi::MATCHUP_ROLES[:ADCSUPPORT]
    else
      role1
    end

    if matchups = Rails.cache.read(matchups: { name: @name1, role: role, elo: @elo })
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
end
