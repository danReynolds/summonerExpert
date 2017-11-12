require 'rails_helper'
require 'spec_contexts.rb'

describe SummonersController, type: :controller do
  include_context 'spec setup'
  include_context 'determinate speech'

  before :each do
    allow(controller).to receive(:summoner_params).and_return(summoner_params)
  end

  describe 'load summoner' do
    let(:summoner_params) do
      { name: 'Hero man', region: 'NA1', champion: 'Tristana', role: 'DUO_CARRY' }
    end
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

  describe 'POST champion_performance_ranking' do
    let(:action) { :champion_performance_ranking }
    let(:summoner_params) do
      {
        name: 'Hero man',
        region: 'NA1',
        role: '',
        list_order: 'highest',
        list_position: 1,
        list_size: 3,
        metric: '',
        position_details: ''
      }
    end

    before :each do
      matches = create_list(:match, 5)
      match_data = [
        { match: { win: true }, summoner_performance: { champion_id: 18, role: 'DUO_CARRY' } },
        { match: { win: false }, summoner_performance: { champion_id: 18, role: 'MIDDLE' } },
        { match: { win: true }, summoner_performance: { champion_id: 20, role: 'MIDDLE' } },
        { match: { win: true }, summoner_performance: { champion_id: 20, role: 'JUNGLE' } },
        { match: { win: false }, summoner_performance: { champion_id: 18, role: 'JUNGLE' } },
      ]
      summoner = Summoner.first
      summoner.update!(name: 'Hero man')
      matches.each_with_index do |match, i|
        summoner_performance = match.summoner_performances.first
        match.update!(winning_team: summoner_performance.team) if match_data[i][:match][:win]
        summoner_performance.update!(
          match_data[i][:summoner_performance].merge({ summoner_id: summoner.id })
        )
      end
    end

    context 'with no champions returned' do
      context 'with no position offset' do
        context 'with complete results' do
          before :each do
            summoner_params[:list_size] = 0
          end

          it 'should indicate that no champions were requested' do
            post action, params: params
            expect(speech).to eq 'No champions were requested.'
          end
        end

        context 'with incomplete results' do
          context 'with a role specified' do
            before :each do
              summoner_params[:role] = 'TOP'
            end

            it 'should indicate that the summoner has not played in that role' do
              post action, params: params
              expect(speech).to eq 'Hero man has not played any games as Top this season in ranked solo queue.'
            end
          end

          context 'with no role specified' do
            before :each do
              summoner_params[:name] = 'inactive player'
            end

            it 'should indicate that the summoner has not played this season.' do
              post action, params: params
              expect(speech).to eq 'inactive player is not an active player in ranked this season.'
            end
          end
        end
      end

      context 'with a position offset' do
        before :each do
          summoner_params[:list_position] = 100
        end

        context 'with complete results' do
          before :each do
            summoner_params[:list_size] = 0
          end

          it 'should indicate that no champions were requested' do
            post action, params: params
            expect(speech).to eq 'No champions were requested.'
          end
        end

        context 'with incomplete results' do
          context 'with a role specified' do
            before :each do
              summoner_params[:role] = 'JUNGLE'
            end

            it 'should indicate that the summoner has not played offset champions this season in that role' do
              post action, params: params
              expect(speech).to eq 'Hero man has only played two champions as Jungle so far this season.'
            end
          end

          context 'with no role specified' do
            it 'should indicate that the summoner has not played offset champions this season' do
              post action, params: params
              expect(speech).to eq 'Hero man has only played two champions so far this season.'
            end
          end
        end
      end
    end

    context  'with a single champion returned' do
    end
  end

  describe 'POST champion_performance_summary' do
    let(:action) { :champion_performance_summary }
    let(:summoner_params) do
      { name: 'Hero man', region: 'NA1', champion: 'Tristana', role: 'DUO_CARRY' }
    end

    before :each do
      @match1 = create(:match)
      @match2 = create(:match)
      summoner_performance = @match1.summoner_performances.first
      summoner_performance.update!(champion_id: 18, role: 'DUO_CARRY')
      summoner_performance.summoner.update!(name: 'Hero man')
      @match2.summoner_performances.first.update(
        champion_id: 18,
        role: 'DUO_CARRY',
        summoner: summoner_performance.summoner
      )
    end

    context 'with no games played as that champion' do
      context 'with a role specified' do
        before :each do
          summoner_params[:role] = 'TOP'
        end

        it 'should indicate that the summoner has not played the champion in that role' do
          post action, params: params
          expect(speech).to eq 'Hero man has not played any games this season as Tristana Top.'
        end
      end

      context 'with no role specified' do
        before :each do
          summoner_params[:role] = nil
          summoner_params[:champion] = 'Zed'
        end

        it 'should indicate that the summoner has not played the champion this season' do
          post action, params: params
          expect(speech).to eq 'Hero man has not played any games this season as Zed.'
        end
      end
    end

    context 'with games played as that champion' do
      context 'with a role specified' do
        it 'should determine the win rate and KDA for the specified role' do
          post action, params: params
          expect(speech).to eq 'Hero man has played Tristana Adc two times with a 100.0% win rate and an overall 2.0/3.0/7.0 KDA.'
        end
      end

      context 'with no role specified' do
        let(:summoner_params) do
          { name: 'Hero man', region: 'NA1', champion: 'Tristana' }
        end

        context 'with one role' do
          it 'should determine the win rate and KDA for the one role' do
            post action, params: params
            expect(speech).to eq 'Hero man has played Tristana Adc two times with a 100.0% win rate and an overall 2.0/3.0/7.0 KDA.'
          end
        end

        context 'with multiple roles' do
          before :each do
            @match2.summoner_performances.first.update(role: 'DUO_SUPPORT')
          end

          it 'should prompt to specify a role' do
            post action, params: params
            expect(speech).to eq 'Hero man has played Tristana two times across Adc and Support. Which role do you want to know about?'
          end
        end
      end
    end
  end

  describe 'POST champion_performance_position' do
    let(:action) { :champion_performance_position }
    let(:summoner_params) do
      {
        name: 'Hero man',
        champion: 'Tristana',
        role: 'DUO_CARRY',
        position_details: 'kills',
        region: 'NA1'
      }
    end

    before :each do
      @match1 = create(:match)
      @match2 = create(:match)
      summoner_performance = @match1.summoner_performances.first
      summoner_performance.update!(champion_id: 18, role: 'DUO_CARRY')
      summoner_performance.summoner.update!(name: 'Hero man')
      @match2.summoner_performances.first.update(
        champion_id: 18,
        role: 'DUO_CARRY',
        summoner: summoner_performance.summoner
      )
    end

    context 'with no games played as that champion' do
      context 'with a role specified' do
        before :each do
          summoner_params[:role] = 'TOP'
        end

        it 'should indicate that the summoner has not played the champion in that role' do
          post action, params: params
          expect(speech).to eq 'Hero man has not played any games this season as Tristana Top.'
        end
      end

      context 'with no role specified' do
        before :each do
          summoner_params[:role] = nil
          summoner_params[:champion] = 'Zed'
        end

        it 'should indicate that the summoner has not played the champion this season' do
          post action, params: params
          expect(speech).to eq 'Hero man has not played any games this season as Zed.'
        end
      end
    end

    context 'with games played as that champion' do
      context 'with a role specified' do
        it 'should determine the position performance for that role' do
          post action, params: params
          expect(speech).to eq 'Hero man has played Tristana Adc two times and averages 2.0 kills.'
        end
      end

      context 'with no role specified' do
        before :each do
          summoner_params[:role] = nil
        end

        context 'with one role' do
          it 'should determine the position performance for the one role' do
            post action, params: params
            expect(speech).to eq 'Hero man has played Tristana Adc two times and averages 2.0 kills.'
          end
        end

        context 'with multiple roles' do
          before :each do
            @match2.summoner_performances.first.update(role: 'DUO_SUPPORT')
          end

          it 'should prompt to specify a role' do
            post action, params: params
            expect(speech).to eq 'Hero man has played Tristana two times across Adc and Support. Which role do you want to know about?'
          end
        end
      end
    end
  end
end
