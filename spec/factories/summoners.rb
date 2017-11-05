FactoryBot.define do
  factory :summoner do
    sequence(:name) { |n| "summoner_#{n}" }
  end
end
