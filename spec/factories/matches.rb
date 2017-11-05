FactoryBot.define do
  factory :match do
    association :team1, factory: :team
    association :team2, factory: :team

    transient do
      summoner_performances_count 10
    end

    after(:create) do |match, evaluator|
      create_list(:summoner_performances, evaluator.summoner_performances_count, match: match)
    end
  end
end
