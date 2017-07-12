Rails.application.routes.draw do
  root to: 'application#status'

  namespace :champions do
    post :title
    post :ally_tips
    post :enemy_tips
    post :ability
    post :cooldown
    post :role_performance_summary
    post :build
    post :ability_order
    post :counters
    post :matchup
    post :ranking
    post :stats
    post :lore
  end

  namespace :items do
    post :show
  end

  namespace :summoners do
    post :show
    post :champion
  end
end
