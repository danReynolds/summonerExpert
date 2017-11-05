FactoryBot.define do
  factory :summoner_performance do
    kills 7
    deaths 3
    assists 1
    role 'DUO_CARRY'

    association :summoner
  end
end
