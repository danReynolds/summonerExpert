class Collection
  SIMILARITY_THRESHOLD = 0.7

  def initialize(**args)
    name = args[:name].strip
    search_key = {}
    search_key[collection_key] = name

    @data = Rails.cache.read(search_key) || match_collection_data(name)
    self.class::RELAY_ACCESSORS.each do |key|
      instance_variable_set("@#{key}", @data[key])
    end
  end

  def match_collection_data(name)
    matcher = Matcher::Matcher.new(name)
    search_key = Hash.new

    if match = matcher.find_match(self.class::COLLECTION.keys, SIMILARITY_THRESHOLD)
      search_key[collection_key] = match.result
      Rails.cache.read(search_key)
    end
  end

  def collection_key
    self.class.collection_key
  end

  def self.collection_key
    self.to_s.downcase
  end
end
