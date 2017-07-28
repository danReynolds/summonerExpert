class Champion < Collection
  include ActiveModel::Validations

  COLLECTION = Rails.cache.read(collection_key.pluralize)
  ACCESSORS = [
    :name, :title, :lore, :passive, :allytips, :enemytips, :id
  ].freeze
  ACCESSORS.each do |accessor|
    attr_accessor accessor
  end

  ABILITIES = {
    first: 0,
    second: 1,
    third: 2,
    fourth: 3
  }.freeze

  validates :name, presence: true, inclusion: COLLECTION.values

  def ability(ability_position)
    @data['spells'][ABILITIES[ability_position]].slice(
      :cooldown,
      :sanitizedDescription,
      :name
    )
  end
end
