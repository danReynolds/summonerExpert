class Item < Collection
  include ActiveModel::Validations
  
  COLLECTION = Rails.cache.read(collection_key.pluralize)
  ACCESSORS = [
    :name, :description
  ].freeze
  ACCESSORS.each do |accessor|
    attr_accessor accessor
  end

  validates :name, presence: true, inclusion: COLLECTION.values
end
