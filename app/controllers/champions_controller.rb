class ChampionsController < ApplicationController
  include RiotApi
  include Sortable
  before_action :load_champion, except: [:ranking]
  before_action :load_role_performance, only: [:ability_order, :build, :counters, :lane]

  MIN_MATCHUPS = 100
  STAT_PER_LEVEL = :perlevel
  HTML_TAGS = /<("[^"]*"|'[^']*'|[^'">])*>/

  METRICS = {
    highestWinrate: 'highest win rate',
    highestCount: 'most frequent'
  }

  def ranking
    role = champion_params[:lane]
    tag = champion_params[:tag]

    champions = Rails.cache.read(:champions)
    rankings = Rails.cache.read(rankings: role)
    rankings = rankings.select { |ranking| ranking[:tags].include?(tag) } unless tag.blank?
    sortable_rankings = Sortable.new({
      collection: rankings
    }.merge(champion_params.slice(:list_position, :list_size, :list_order)))

    rankings = sortable_rankings.sort.map do |role_performance|
      champions[role_performance[:key]][:name]
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

  def ability_order
    args = {
      name: @champion.name,
      metric: METRICS[champion_params[:metric].to_sym],
      ability_order: @role_performance.ability_order(champion_params[:metric]),
      elo: @role_performance.elo.humanize,
      role: @role_performance.role.humanize
    }
    render json: {
      speech: ApiResponse.get_response({ champions: :ability_order }, args)
    }
  end

  def build
    build = @role_performance[:items][:highestWinPercent][:items].map do |item|
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

    shared_roles = @champion.roles.map do |role_performance|
      role_performance[:role]
    end & other_champion.roles.map do |role_performance|
      role_performance[:role]
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
    matchups = @role_performance[:matchups].select do |matchup|
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
    overall = @role_performance[:overallPosition]
    role_size = Rails.cache.read(rankings: @role).length.en.numwords
    change = overall[:change] > 0 ? 'better' : 'worse'

    render json: {
      speech: (
        "#{@champion.name} got #{change} in the last patch and is currently " \
        "ranked #{overall[:position].en.ordinate} out of #{role_size} with a " \
        "#{@role_performance[:patchWin].last}% win rate and a " \
        "#{@role_performance[:patchPlay].last}% play rate as #{@role}."
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
      speech: ApiResponse.get_response({ champions: :ability }, args)
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

  def lore
    args = { name: @champion.name, lore: @champion.lore }
    render json: {
      speech: ApiResponse.get_response({ champions: :lore }, args)
    }
  end

  def title
    args = { title: @champion.title, name: @champion.name }
    render json: {
      speech: ApiResponse.get_response({ champions: :title }, args)
    }
  end

  def ally_tips
    tip = remove_html_tags(@champion.allytips.sample.to_s)
    args = { name: @champion.name, tip: tip }

    render json: {
      speech: ApiResponse.get_response({ champions: :allytips }, args)
    }
  end

  def enemy_tips
    tip = remove_html_tags(@champion.enemytips.sample.to_s)
    args = { name: @champion.name, tip: tip }

    render json: {
      speech: ApiResponse.get_response({ champions: :enemytips }, args)
    }
  end

  private

  def remove_html_tags(speech)
    speech.gsub(HTML_TAGS, '')
  end

  def load_champion
    @champion = Champion.new(name: champion_params[:name])

    unless @champion.valid?
      render json: { speech: @champion.error_message }
      return false
    end
  end

  def ask_for_role_response(name)
    {
      speech: ApiResponse.get_response(
        { champions: { followups: :ask_for_role } },
        { name: name }
      ),
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

  def load_role_performance
    elo = champion_params[:elo]
    role = champion_params[:role]

    @role_performance = RolePerformance.new(
      elo: elo,
      role: role,
      name: @champion.name
    )

    unless @role_performance.valid?
      if role.blank?
        render json: ask_for_role_response(@champion.name)
      else
        args = {
          name: @champion.name,
          role: role.humanize,
          elo: elo.humanize
        }
        render json: {
          speech: ApiResponse.get_response({ champions: { errors: :does_not_play } }, args)
        }
      end
      return false
    end
  end

  def tag_message(tag, size)
    tag.blank? ? 'champion'.pluralize(size) : tag.en.downcase.pluralize(size)
  end

  def champion_params
    params.require(:result).require(:parameters).permit(
      :name, :champion1, :ability_position, :rank, :role, :list_size, :list_position,
      :list_order, :stat, :level, :tag, :elo, :metric
    )
  end
end
