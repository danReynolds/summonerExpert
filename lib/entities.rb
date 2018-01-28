class Entities
  relay_entities = [
    :summoner, :role, :champion, :sort_type, :total_performances,
    :real_size, :requested_size, :filtered_size, :list_order, :filtered_position_offset,
    :summoners, :real_size_summoner_conjugation, :name, :champion2, :position_value,
    :winrate, :kills, :deaths, :assists, :count
  ].each do |entity|
    define_singleton_method(entity) do |value|
      value.to_s
    end
  end

  class << self
    def recency(recent_value)
      if recent_value
        return random_response([
          'recently',
          'lately',
          'of late'
        ])
      else
        return random_response([
          'so far this season',
          'this season',
          'as of this season'
        ])
      end
    end

    def summoners(summoners)
      return '' unless summoners.present?
      summoners.en.conjunction(article: false)
    end

    def list_position(position)
      position === 1.en.ordinate ? '' : position
    end

    def random_response(values)
      values.sample
    end
  end
end
