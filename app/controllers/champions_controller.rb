class ChampionsController < ApplicationController
  include RiotApi
  include Sortable
  before_action :load_champion, except: [:ranking]
  before_action :verify_role, only: [:ability_order, :build, :counters, :lane]

  MIN_MATCHUPS = 100
  STAT_PER_LEVEL = :perlevel
  HTML_TAGS = /<("[^"]*"|'[^']*'|[^'">])*>/

  def ranking
    role = champion_params[:lane]
    tag = champion_params[:tag]

    champions = Rails.cache.read(:champions)
    rankings = Rails.cache.read(rankings: role)
    rankings = rankings.select { |ranking| ranking[:tags].include?(tag) } unless tag.blank?
    sortable_rankings = Sortable.new({
      collection: rankings
    }.merge(champion_params.slice(:list_position, :list_size, :list_order)))

    rankings = sortable_rankings.sort.map do |role_data|
      champions[role_data[:key]][:name]
    end
    list_size_message = sortable_rankings.list_size_message
    list_position_message = sortable_rankings.list_position_message
    topic_message = tag_message(tag, rankings.size)

    render json: {
      speech: (
        "#{insufficient_champions_message(rankings.size, 'ranking')}The " \
        "#{list_position_message}#{sortable_rankings.list_order} " \
        "#{list_size_message}#{topic_message} in #{role} " \
        "#{"is".en.plural_verb(sortable_rankings.list_size)} " \
        "#{rankings.en.conjunction(article: false)}."
      )
    }
  end

  def stats
    name = @champion.name
    stats = @champion.stats
    stat = champion_params[:stat]
    level = champion_params[:level].to_i
    stat_value = stats[stat]
    stat_name = RiotApi::STATS[stat.to_sym]
    level_message = ''

    if stat_modifier = stats["#{stat}#{STAT_PER_LEVEL}"]
      return render json: ask_for_level_response unless level.positive?

      level_message = " at level #{level}"
      stat_value += stat_modifier * (level - 1)
    end

    render json: {
      speech: (
        "#{name} has #{stat_value.round} #{stat_name}#{level_message}."
      )
    }
  end

  def description
    play_style = @champion.tags.en.conjunction
    roles = @champion.roles.map { |variant| variant[:role] }
      .en.conjunction(article: false)

    render json: {
      speech: (
        "#{@champion.name}, the #{@champion.title}, is #{play_style} and " \
        "is played as #{roles}."
      )
    }
  end

  def ability_order
    order = parse_ability_order(@role_data[:skills][:highestWinPercent][:order])
    render json: {
      speech: (
        "The highest win rate on #{@champion.name} #{@role} has you start " \
        "#{order[:firstOrder].join(', ')} and then max " \
        "#{order[:maxOrder].join(', ')}."
      )
    }
  end

  def build
    build = @role_data[:items][:highestWinPercent][:items].map do |item|
      item[:name]
    end.en.conjunction(article: false)

    render json: {
      speech: (
        "The highest win rate build for #{@champion.name} #{@role} is #{build}."
      )
    }
  end

  def matchup
    role = champion_params[:lane]
    champion_query = champion_params[:champion1].strip
    other_champion = Champion.new(name: champion_query)

    unless other_champion.valid?
      render json: { speech: other_champion.error_message }
      return false
    end

    shared_roles = @champion.roles.map do |role_data|
      role_data[:role]
    end & other_champion.roles.map do |role_data|
      role_data[:role]
    end

    if shared_roles.length.zero? || !role.blank? && !shared_roles.include?(role)
      return render json: {
        speech: (
          "#{@champion.name} and #{other_champion.name} do not typically " \
          "play against eachother in #{role.blank? ? 'any role' : role}."
        )
      }
    end

    if role.blank?
      if shared_roles.length == 1
        role = shared_roles.first
      else
        return render json: ask_for_role_response
      end
    end

    champion_role = @champion.find_by_role(role)
    other_champion_role = other_champion.find_by_role(role)

    matchup = champion_role[:matchups].detect do |matchup|
      matchup[:key] == other_champion.key
    end
    change = matchup[:winRateChange] > 0 ? 'better' : 'worse'

    return render json: {
      speech: (
        "#{@champion.name} got #{change} against #{other_champion.name} in " \
        "the latest patch and has a win rate of #{matchup[:winRate]}% " \
        "against #{other_champion.title} in #{role}."
      )
    }
  end

  def counters
    matchups = @role_data[:matchups].select do |matchup|
      matchup[:games] >= MIN_MATCHUPS
    end

    if matchups.blank?
      return render json: {
        speech: (
          "There is not enough data for #{@champion.name} in the current patch."
        )
      }
    end

    sortable_counters = Sortable.new({
      collection: matchups,
      sort_order: -> matchup { matchup[:statScore] }
    }.merge(champion_params.slice(:list_size, :list_position, :list_order)))
    champions = Rails.cache.read(:champions)

    counters = sortable_counters.sort.map do |counter|
      "#{champions[counter[:key]][:name]} at a " \
      "#{(100 - counter[:winRate]).round(2)}% win rate"
    end
    list_size_message = sortable_counters.list_size_message
    list_position_message = sortable_counters.list_position_message
    list_size = sortable_counters.list_size.to_i

    render json: {
      speech: (
        "#{insufficient_champions_message(counters.size, 'counter')}The " \
        "#{list_position_message}#{sortable_counters.list_order} " \
        "#{list_size_message}#{'counter'.en.pluralize(counters.size)} " \
        "for #{@champion.name} #{@role} #{'is'.en.plural_verb(counters.size)} " \
        "#{counters.en.conjunction(article: false)}."
      )
    }
  end

  def lane
    overall = @role_data[:overallPosition]
    role_size = Rails.cache.read(rankings: @role).length.en.numwords
    change = overall[:change] > 0 ? 'better' : 'worse'

    render json: {
      speech: (
        "#{@champion.name} got #{change} in the last patch and is currently " \
        "ranked #{overall[:position].en.ordinate} out of #{role_size} with a " \
        "#{@role_data[:patchWin].last}% win rate and a " \
        "#{@role_data[:patchPlay].last}% play rate as #{@role}."
      )
    }
  end

  def ability
    ability_position = champion_params[:ability_position]
    ability = @champion.ability(ability_position.to_sym)
    args = {
      position: ability_position,
      description: ability[:sanitizedDescription],
      champion_name: @champion.name,
      ability_name: ability[:name]
    }

    render json: {
      speech: ApiResponse.get_response(:champions, :ability, args)
    }
  end

  def cooldown
    ability = champion_params[:ability].to_sym
    spell = @champion.spells[RiotApi::ABILITIES[ability]]
    rank = champion_params[:rank].split(' ').last.to_i

    render json: {
      speech: (
        "#{@champion.name}'s #{ability} ability, #{spell[:name]}, has a " \
        "cooldown of #{spell[:cooldown][rank - 1].to_i} seconds at rank #{rank}."
      )
    }
  end

  # Relays the requested information to the champion model and returns an
  # assorted response
  def relay_action
    relay_accessor = champion_params[:relay_accessor].to_sym
    raise unless Champion::RELAY_ACCESSORS.include?(relay_accessor)
    args = champion_params
    args[relay_accessor] = @champion.send(relay_accessor)

    render json: {
      speech: ApiResponse.get_response(:champions, relay_accessor, champion_params)
    }
  end

  def title
    args = {
      title: @champion.title,
      name: @champion.name
    }
    render json: {
      speech: ApiResponse.get_response(:champions, :title, args)
    }
  end

  def ally_tips
    tip = remove_html_tags(@champion.allytips.sample.to_s)
    render json: {
      speech: "Here's a tip for playing as #{@champion.name}: #{tip}"
    }
  end

  def enemy_tips
    tip = remove_html_tags(@champion.enemytips.sample.to_s)
    render json: {
      speech: "Here's a tip for playing against #{@champion.name}: #{tip}"
    }
  end

  private

  def insufficient_champions_message(size, type)
    return '' if champion_params[:list_size].to_i == size
    "The current patch only has enough data for #{size.en.numwords} " \
    "#{type.en.pluralize(size)}. "
  end

  def parse_ability_order(abilities)
    first_abilities = abilities.first(3)

    # Handle the case where you take two of the same ability to begin
    if first_abilities == first_abilities.uniq
      max_order_abilities = abilities[3..-1]
    else
      first_abilities = abilities.first(4)
      max_order_abilities = abilities[4..-1]
    end

    {
      firstOrder: first_abilities,
      maxOrder: max_order_abilities.uniq.reject { |ability| ability == 'R' }
    }
  end

  def remove_html_tags(speech)
    speech.gsub(HTML_TAGS, '')
  end

  def load_champion
    @champion = Champion.new(name: champion_params[:name])
  end

  def do_not_play_response(name, role)
    {
      speech: (
        <<~HEREDOC
          There is no recommended way to play #{name} as #{role}. This is not
          a good idea in the current meta.
        HEREDOC
      )
    }
  end

  def ask_for_role_response
    {
      speech: 'What role are they in?',
      data: {
        google: {
          expect_user_response: true # Used to keep mic open when a response is needed
        }
      }
    }
  end

  def ask_for_level_response
    {
      speech: 'What level is the champion?',
      data: {
        google: {
          expect_user_response: true # Used to keep mic open when a response is needed
        }
      }
    }
  end

  def verify_role
    @role = champion_params[:lane]
    unless @role_data = @champion.find_by_role(@role)
      if @role.blank?
        render json: ask_for_role_response
      else
        render json: do_not_play_response(@champion.name, @role)
      end
      return false
    end

    @role = @role_data[:role] if @role.blank?
  end

  def tag_message(tag, size)
    tag.blank? ? 'champion'.pluralize(size) : tag.en.downcase.pluralize(size)
  end

  def champion_params
    params.require(:result).require(:parameters).permit(
      :name, :champion1, :ability_position, :rank, :lane, :list_size, :list_position,
      :list_order, :stat, :level, :tag, :relay_accessor
    )
  end
end
