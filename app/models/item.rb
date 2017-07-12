class Item < Collection
  COLLECTION = Rails.cache.read(collection_key.pluralize)
end
