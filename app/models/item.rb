class Item < Collection
  include ActiveModel::Validations
  ACCESSORS = [
    :cost_analysis, :name, :description
  ].freeze
  ACCESSORS.each do |accessor|
    attr_accessor accessor
  end

  validates :name, presence: true
end
