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
        list_size: 2,
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
      summoner = create(:summoner, name: 'Hero man')
      matches.each_with_index do |match, i|
        summoner_performance = match.summoner_performances.first
        if match_data[i][:match][:win]
          match.update!(winning_team: summoner_performance.team)
        else
          match.update!(winning_team: summoner_performance.team == match.team1 ? match.team2 : match.team1)
        end
        summoner_performance.update!(
          match_data[i][:summoner_performance].merge({ summoner_id: summoner.id })
        )
      end
    end

    context 'with a metric and position details specified' do
      before :each do
        summoner_params[:metric] = :count
        summoner_params[:position_details] = 'kills'
      end

      it 'should sort the ranking by the metric' do
        post action, params: params
        expect(speech).to eq "The champions played by Hero man with the summoner's highest games played are Tristana and Nunu."
      end
    end

    context 'with only a metric specified' do
      context 'with a count metric given' do
        before :each do
          summoner_params[:metric] = :count
        end

        it 'should rank by games played' do
          post action, params: params
          expect(speech).to eq "The champions played by Hero man with the summoner's highest games played are Tristana and Nunu."
        end
      end

      context 'with a KDA metric given' do
        before :each do
          Match.last.summoner_performances.first.update!(kills: 10000)
          summoner_params[:metric] = :KDA
        end

        it 'should rank by average KDA' do
          post action, params: params
          expect(speech).to eq "The champions played by Hero man with the summoner's highest KDA are Tristana and Nunu."
        end
      end

      context 'with a winrate metric given' do
        before :each do
          summoner_params[:metric] = :winrate
        end

        it 'should rank by overall winrate' do
          post action, params: params
          expect(speech).to eq "The champions played by Hero man with the summoner's highest win rate are Nunu and Tristana."
        end
      end
    end

    context 'with only a position details specified' do
      before :each do
        summoner_params[:position_details] = :wards_placed
        Match.last.summoner_performances.first.update!(wards_placed: 10000)
      end

      it 'should rank by the position details' do
        post action, params: params
        expect(speech).to eq "The champions played by Hero man with the summoner's highest wards placed are Tristana and Nunu."
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

    context 'with a single champion returned' do
      before :each do
        summoner_params[:list_size] = 1
      end

      context 'with no position offset' do
        context 'with a complete response' do
          context 'with a role specified' do
            before :each do
              summoner_params[:role] = 'MIDDLE'
            end

            it 'should return the single highest ranking for that role' do
              post action, params: params
              expect(speech).to eq 'The champion played by Hero man with the highest win rate in Middle is Nunu.'
            end
          end

          context 'with no role specified' do
            it 'should return the single highest ranking for any role' do
              post action, params: params
              expect(speech).to eq 'The champion played by Hero man with the highest win rate is Nunu.'
            end
          end
        end

        context 'with an incomplete response' do
          before :each do
            summoner_params[:name] = 'inactive player'
          end

          context 'with a role specified' do
            before :each do
              summoner_params[:role] = 'Top'
            end

            it 'should indicate that the player is inactive this season' do
              post action, params: params
              expect(speech).to eq 'inactive player is not an active player in ranked this season.'
            end
          end

          context 'with no role specified' do
            it 'should indicate that the player is inactive this season' do
              post action, params: params
              expect(speech).to eq 'inactive player is not an active player in ranked this season.'
            end
          end
        end
      end

      context 'with a position offset' do
        before :each do
          summoner_params[:list_position] = 2
        end

        context 'with a complete response' do
          context 'with a role specified' do
            before :each do
              summoner_params[:role] = 'MIDDLE'
            end

            it 'should return the offset highest champion for that role' do
              post action, params: params
              expect(speech).to eq 'The champion played by Hero man with the second highest win rate in Middle is Tristana.'
            end
          end

          context 'with no role specified' do
            it 'should return the offset highest champion for any role' do
              post action, params: params
              expect(speech).to eq 'The champion played by Hero man with the second highest win rate is Tristana.'
            end
          end
        end

        context 'with an incomplete response' do
          before :each do
            summoner_params[:list_size] = 3
          end

          context 'with a role specified' do
            before :each do
              summoner_params[:role] = 'MIDDLE'
            end

            it 'should indicate the results are incomplete and return the one champion for that role' do
              post action, params: params
              expect(speech).to eq 'Hero man has only played two champions so far this season as Middle. The champion played by Hero man with the second highest win rate as Middle is Tristana.'
            end
          end

          context 'with no role specified' do
            it 'should indicate the results are incomplete and return the one champion' do
              post action, params: params
              expect(speech).to eq 'Hero man has only played two champions so far this season. The champion played by Hero man with the second highest win rate is Tristana.'
            end
          end
        end
      end
    end

    context 'with multiple champions returned' do
      context 'with no position offset' do
        context 'with a complete response' do
          context 'with a role specified' do
            before :each do
              summoner_params[:role] = 'MIDDLE'
            end

            it 'should provide rankings for the champions in that role' do
              post action, params: params
              expect(speech).to eq "The champions played by Hero man with the summoner's highest win rate in Middle are Nunu and Tristana."
            end
          end

          context 'with no role specified' do
            it 'should provide rankings for the champions in any role' do
              post action, params: params
              expect(speech).to eq "The champions played by Hero man with the summoner's highest win rate are Nunu and Tristana."
            end
          end
        end

        context 'with an incomplete response' do
          before :each do
            summoner_params[:list_size] = 3
          end

          context 'with a role specified' do
            before :each do
              summoner_params[:role] = 'MIDDLE'
            end

            it 'should return an incomplete ranking of champions in that role' do
              post action, params: params
              expect(speech).to eq "Hero man has only played two champions so far this season as Middle. The champions played by Hero man with the summoner's highest win rate as Middle are Nunu and Tristana."
            end
          end

          context 'with no role specified' do
            it 'should return an incomplete ranking of champions in any role' do
              post action, params: params
              expect(speech).to eq "Hero man has only played two champions so far this season. The champions played by Hero man with the summoner's highest win rate are Nunu and Tristana."
            end
          end
        end
      end

      context 'with a position offset' do
        before :each do
          summoner_params[:list_position] = 2
          Match.last.summoner_performances.first.update!(champion_id: 30, role: 'MIDDLE')
        end

        context 'with complete rankings' do
          context 'with a role specified' do
            before :each do
              summoner_params[:role] = 'MIDDLE'
            end

            it 'should return a complete ranking with champions from that role' do
              post action, params: params
              expect(speech).to eq 'The second through third champions played by Hero man with the highest win rate in Middle are Karthus and Tristana.'
            end
          end

          context 'with no role specified' do
            it 'should return a complete ranking with champions from all roles' do
              post action, params: params
              expect(speech).to eq 'The second through third champions played by Hero man with the highest win rate are Tristana and Karthus.'
            end
          end
        end

        context 'with incomplete rankings' do
          before :each do
            summoner_params[:list_size] = 3
          end

          context 'with a role specified' do
            before :each do
              summoner_params[:role] = 'MIDDLE'
            end

            it 'should return incomplete rankings for that role' do
              post action, params: params
              expect(speech).to eq 'Hero man has only played three champions so far this season as Middle. The second through third champions played by Hero man with the highest win rate as Middle are Karthus and Tristana.'
            end
          end

          context 'with no role specified' do
            it 'should return incomplete rankings across all roles' do
              post action, params: params
              expect(speech).to eq 'Hero man has only played three champions so far this season. The second through third champions played by Hero man with the highest win rate are Tristana and Karthus.'
            end
          end
        end
      end
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
          summoner_params[:role] = ''
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
          summoner_params[:role] = ''
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
