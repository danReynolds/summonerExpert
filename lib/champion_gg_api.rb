class ChampionGGApi < ExternalApi
  @api_key = ENV['CHAMPION_GG_API_KEY']
  @api = load_api('champion_gg_api')

  # ELO Options
  ELOS = {
    BRONZE: 'BRONZE',
    SILVER: 'SILVER',
    GOLD: 'GOLD',
    PLATINUM: 'PLATINUM',
    PLATINUM_PLUS: '' # It is the default if you send nothing
  }.freeze

  # Role Options
  ROLES = {
    TOP: 'TOP',
    MIDDLE: 'MIDDLE',
    JUNGLE: 'JUNGLE',
    DUO_CARRY: 'ADC', # Champion is playing ADC
    DUO_SUPPORT: 'SUPPORT' # Champion is playing Support
  }.freeze

  # Matchup Role Options
  # Who you are comparing the champion with/against in the matchup
  MATCHUP_ROLES = {
    TOP: 'TOP',
    JUNGLE: 'JUNGLE',
    MIDDLE: 'MIDDLE',
    SYNERGY: 'SYNERGY', # Matchup compares the champion to its lane partner
    ADCSUPPORT: 'ADCSUPPORT', # Matchup compares the champion to its bot lane opponent of the other role
    DUO_CARRY: 'DUO_CARRY', # Matchup compares the champion as an ADC to the opposing ADC
    DUO_SUPPORT: 'DUO_SUPPORT' # Matchup compares the champion as a Support to the opposing Support
  }.freeze

  # Champion Positions currently being ranked and cached
  POSITIONS = {
    deaths: 'deaths',
    winRates: 'win rate',
    minionsKilled: 'creep score',
    banRates: 'ban rate',
    assists: 'assists',
    kills: 'kills',
    playRates: 'play rate',
    damageDealt: 'damage dealt',
    goldEarned: 'gold earned',
    overallPerformanceScore: 'overall performance',
    totalHeal: 'healing done',
    killingSprees: 'average killing sprees',
    totalDamageTaken: 'total damage taken',
    averageGamesScore: 'average games played',
    totalPositions: '', # These 2 positions are useful internally but are not requested by users
    previousOverallPerformanceScore: ''
  }.freeze

  class << self
    def get_champion_roles(**args)
      url = replace_url(@api[:champion_roles], args)
      fetch_response(url)
    end
  end
end
