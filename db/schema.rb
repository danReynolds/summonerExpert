# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20171023042518) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "bans", force: :cascade do |t|
    t.datetime "created_at",              null: false
    t.datetime "updated_at",              null: false
    t.integer  "champion_id"
    t.integer  "order"
    t.integer  "summoner_performance_id"
  end

  create_table "matches", force: :cascade do |t|
    t.datetime "created_at",                  null: false
    t.datetime "updated_at",                  null: false
    t.bigint   "game_id"
    t.integer  "queue_id"
    t.integer  "season_id"
    t.string   "region_id"
    t.integer  "winning_team_id"
    t.integer  "first_blood_id"
    t.integer  "first_tower_id"
    t.integer  "first_inhibitor_id"
    t.integer  "first_baron_id"
    t.integer  "first_rift_herald_id"
    t.integer  "team1_id"
    t.integer  "team2_id"
    t.integer  "first_blood_summoner_id"
    t.integer  "first_tower_summoner_id"
    t.integer  "first_inhibitor_summoner_id"
    t.integer  "game_duration"
  end

  create_table "summoner_performances", force: :cascade do |t|
    t.datetime "created_at",                          null: false
    t.datetime "updated_at",                          null: false
    t.integer  "team_id"
    t.bigint   "summoner_id"
    t.integer  "match_id"
    t.integer  "participant_id"
    t.integer  "champion_id"
    t.integer  "spell1_id"
    t.integer  "spell2_id"
    t.integer  "kills"
    t.integer  "deaths"
    t.integer  "assists"
    t.string   "role"
    t.integer  "largest_killing_spree"
    t.integer  "total_killing_sprees"
    t.integer  "double_kills"
    t.integer  "triple_kills"
    t.integer  "quadra_kills"
    t.integer  "penta_kills"
    t.integer  "total_damage_dealt"
    t.integer  "magic_damage_dealt"
    t.integer  "physical_damage_dealt"
    t.integer  "true_damage_dealt"
    t.integer  "largest_critical_strike"
    t.integer  "total_damage_dealt_to_champions"
    t.integer  "magic_damage_dealt_to_champions"
    t.integer  "physical_damage_dealt_to_champions"
    t.integer  "true_damage_dealt_to_champions"
    t.integer  "total_healing_done"
    t.integer  "vision_score"
    t.integer  "cc_score"
    t.integer  "gold_earned"
    t.integer  "turrets_killed"
    t.integer  "inhibitors_killed"
    t.integer  "total_minions_killed"
    t.integer  "vision_wards_bought"
    t.integer  "sight_wards_bought"
    t.integer  "wards_placed"
    t.integer  "wards_killed"
    t.integer  "neutral_minions_killed"
    t.integer  "item0_id"
    t.integer  "item1_id"
    t.integer  "item2_id"
    t.integer  "item3_id"
    t.integer  "item4_id"
    t.integer  "item5_id"
    t.integer  "item6_id"
    t.integer  "neutral_minions_killed_team_jungle"
    t.integer  "neutral_minions_killed_enemy_jungle"
  end

  create_table "summoners", force: :cascade do |t|
    t.string   "name"
    t.integer  "account_id"
    t.bigint   "summoner_id"
    t.datetime "created_at",  null: false
    t.datetime "updated_at",  null: false
    t.string   "region"
  end

  create_table "teams", force: :cascade do |t|
    t.datetime "created_at",       null: false
    t.datetime "updated_at",       null: false
    t.integer  "team_id"
    t.integer  "tower_kills"
    t.integer  "inhibitor_kills"
    t.integer  "baron_kills"
    t.integer  "dragon_kills"
    t.integer  "riftherald_kills"
  end

end
