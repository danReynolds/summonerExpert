class Champion < Collection
  COLLECTION = Rails.cache.read(collection_key.pluralize)
  RELAY_ACCESSORS = [
    :name, :title, :lore, :passive
  ].freeze
  RELAY_ACCESSORS.each do |accessor|
    attr_accessor accessor
  end

  ABILITIES = {
    first: 0,
    second: 1,
    third: 2,
    fourth: 3
  }.freeze

  def ability(ability_position)
    @data['spells'][ABILITIES[ability_position]].slice(:sanitizedDescription, :name)
  end
end
