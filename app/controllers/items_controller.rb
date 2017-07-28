class ItemsController < ApplicationController
  include RiotApi
  before_action :load_item

  def description
    costs = @item.costs
    args = {
      name: @item.name,
      description: @item.sanitizedDescription,
      total_cost: costs['total'],
      sell_cost: costs['sell']
    }

    render json: {
      speech: ApiResponse.get_response({ items: :description }, args)
    }
  end

  def build
    args = {
      name: @item.name,
      item_names: @item.build.en.conjunction(article: false)
    }

    render json: {
      speech: ApiResponse.get_response({ items: :build }, args)
    }
  end

  private

  def load_item
    @item = Item.new(name: item_params[:name])

    unless @item.valid?
      render json: { speech: @item.error_message }
      return false
    end
  end

  def item_params
    params.require(:result).require(:parameters).permit(:name)
  end

  def item_not_found_response(name)
    { speech: "I could not find an item called '#{name}'." }
  end

  def no_item_specified_response
    {
      speech: 'What item are you looking for?',
      data: {
        google: {
          expect_user_response: true # Used to keep mic open when a response is needed
        }
      }
    }
  end
end
