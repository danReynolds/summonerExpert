class DataDog
  @client = Dogapi::Client.new(ENV['DATA_DOG_KEY'])

  HOST = 'ServerManager'
  EVENTS = {
    CHAMPIONGG_CHAMPION_PERFORMANCE: 'Champion GG Performance Event',
    RIOT_CHAMPIONS: 'Riot Champions Event',
    RIOT_ITEMS: 'Riot Items Event',
    RIOT_MATCHES: 'Riot Matches Event'
  }

  class << self
    def event(type, **args)
      @client.emit_event(
        Dogapi::Event.new("#{type}. #{args}"),
        host: HOST
      )
    end
  end
end
