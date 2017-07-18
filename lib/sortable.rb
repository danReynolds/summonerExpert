module Sortable
  class Sortable
    ORDER = {
      highest: :highest,
      lowest: :lowest
    }.freeze

    ACCESSORS = [
      :list_position, :list_size, :list_order, :collection, :sort_value
    ].freeze
    ACCESSORS.each do |accessor|
      attr_accessor accessor
    end

    DEFAULTS = {
      list_position: 1,
      list_size: 1,
      list_order: ORDER[:desc],
      collection: []
    }.freeze

    def initialize(args = {})
      args = args.with_indifferent_access
      self.class::ACCESSORS.each do |key|
        instance_variable_set("@#{key}", args[key].present? ? args[key] : DEFAULTS[key])
      end
    end

    def sort
      collection = @collection
      collection = collection.sort_by(&@sort_value) if @sort_value
      collection = collection[((@list_position.to_i) - 1)..-1]
      collection.reverse! if @list_order.to_sym == ORDER[:lowest]
      collection.first(@list_size.to_i)
    end

    def list_size_message
      size = [@list_size.to_i, collection.length].min
      size == 1 ? '' : "#{size.en.numwords} "
    end

    def list_position_message
      @list_position.to_i == 1 ? '' : "#{@list_position.en.ordinate} "
    end
  end
end
