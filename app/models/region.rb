class Region
  include ActiveModel::Validations
  attr_accessor :region

  REGIONS = %w(br1 eun1 euw1 jp1 kr la1 la2 na1 oc1 ru tr1).freeze

  validates :region, inclusion: { in: REGIONS }

  def initialize(attributes = {})
    @region = attributes[:region]
  end

  def error_message
    errors.messages.map do |key, value|
      "#{key} #{value.first}"
    end.en.conjunction(article: false)
  end
end
