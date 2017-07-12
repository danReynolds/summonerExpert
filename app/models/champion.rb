class Champion < Collection
  include ActiveModel::Validations
  ACCESSORS = [
    :name, :roles, :stats, :tags, :title, :passive, :spells, :allytips,
    :enemytips, :key, :id
  ].freeze
  ACCESSORS.each do |accessor|
    attr_accessor accessor
  end

  validates :name, presence: true

  def find_by_role(role)
    if role.blank?
      return @roles.length == 1 ? @roles.first : nil
    end

    @roles.detect do |role_data|
      role_data[:role] == role
    end
  end

  def win_percent(role)
    return unless role = find_by_role(role)
    role[:patchWin].last.round(2)
  end
end
