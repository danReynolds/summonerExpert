require 'rails_helper'
require 'spec_contexts.rb'

describe SummonersController, type: :controller do
  include_context 'spec setup'
  include_context 'determinate speech'

  before :each do
    allow(controller).to receive(:summoner_params).and_return(summoner_params)
  end

  describe 'POST performance_summary' do
    let(:action) { :performance_summary }
    let(:external_response) do
      JSON.parse(File.read('external_response.json'))
        .with_indifferent_access[:summoners][action]
    end
    let(:summoner_params) do
      { name: 'Wingilote', region: 'na1', queue: 'RANKED_SOLO_5x5' }
    end

    before :each do
      allow(RiotApi::RiotApi).to receive(:fetch_response).and_return(
        external_response
      )
    end

    context 'when cached' do
      it 'should not make an API request' do
        post action, params: params
        post action, params: params

        expect(RiotApi::RiotApi).to have_received(:get_summoner_id).once
        expect(RiotApi::RiotApi).to have_received(:get_summoner_queues).once
      end
    end

    context 'with no queue information' do
      before :each do
        allow(RiotApi::RiotApi).to receive(:fetch_response).and_return({})
      end

      it 'should indicate that the summoner does not play in that queue' do
        post action, params: params
        expect(speech).to eq 'Wingilote is not currently an active player in Solo Queue.'
      end
    end

    it 'should return the summoner information' do
      post action, params: params
      expect(speech).to eq 'Wingilote is ranked Gold V with 84 LP in Solo Queue. The summoner currently has a 50.16% win rate and is not on a hot streak.'
    end

    it 'should vary the information by queue' do
      summoner_params[:queue] = 'RANKED_FLEX_SR'
      post action, params: params
      expect(speech).to eq 'Wingilote is ranked Bronze I with 28 LP in Flex Queue. The summoner currently has a 60.78% win rate and is not on a hot streak.'
    end
  end

  describe 'POST champion_performance_summary' do
    let(:action) { :champion_performance_summary }
    let(:summoner_params) do
      { name: 'Sir Cold', region: 'NA1', champion: 'Pantheon' }
    end

    context 'with a role specified' do
      let(:summoner_params) do
        { name: 'RivetingObstacle', region: 'NA1', champion: 'Sivir', role: 'DUO_CARRY' }
      end

      before :all do
        Summoner.find_by_name('RivetingObstacle').summoner_performances.last.update_attribute(:role, 'DUO_SUPPORT')
      end

      after :all do
        Summoner.find_by_name('RivetingObstacle').summoner_performances.last.update_attribute(:role, 'DUO_CARRY')
      end

      it 'should only include performances for the specified role' do
        post action, params: params
        expect(speech).to eq 'RivetingObstacle has played Sivir Adc in one game with a 7.0/6.0/18.0 KDA.'
      end
    end

    context 'with one role' do
      context 'with a single game' do
        it 'should only list the single role played' do
          post action, params: params
          expect(speech).to eq 'Sir Cold has played Pantheon one time with a 2.0/8.0/14.0 KDA and in the following roles: Jungle.'
        end
      end

      context 'with multiple games' do
        let(:summoner_params) do
          { name: 'RivetingObstacle', region: 'NA1', champion: 'Sivir' }
        end

        it 'should list the precentage of play in each role' do
          post action, params: params
          expect(speech).to eq 'RivetingObstacle has played Sivir two times with a 3.5/3.0/9.0 KDA and in the following roles: Adc.'
        end
      end
    end

    context 'with multiple roles' do
      let(:summoner_params) do
        { name: 'RivetingObstacle', region: 'NA1', champion: 'Sivir' }
      end

      before :all do
        Summoner.find_by_name('RivetingObstacle').summoner_performances.last.update_attribute(:role, 'DUO_SUPPORT')
      end

      after :all do
        Summoner.find_by_name('RivetingObstacle').summoner_performances.last.update_attribute(:role, 'DUO_CARRY')
      end

      it 'should list the roles played' do
        post action, params: params
        expect(speech).to eq 'RivetingObstacle has played Sivir two times with a 3.5/3.0/9.0 KDA and in the following roles: Support 50.0% and Adc 50.0%.'
      end
    end
  end
end
