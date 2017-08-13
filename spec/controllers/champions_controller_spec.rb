require 'rails_helper'

describe ChampionsController, type: :controller do
  let(:resources) do
    JSON.parse(File.read('api.json')).with_indifferent_access[:resources]
  end
  let(:params) do
    res = resources.detect do |res|
      res[:name] == "champions/#{action}"
    end
    JSON.parse(res[:body][:text])
  end

  def speech
    JSON.parse(response.body).with_indifferent_access[:speech]
  end

  # Override the indeterminate nature of the speech templates returned
  shared_context 'determinate speech' do
    before :each do
      allow(ApiResponse).to receive(:random_response) do |responses|
        responses.first
      end
    end
  end

  describe 'POST ranking' do
    include_context 'determinate speech'
    let(:action) { :ranking }
    let(:champion_params) do
      {
        list_size: '3',
        role: 'TOP',
        list_position: '1',
        list_order: 'highest',
        elo: 'SILVER',
        position: 'kills'
      }
    end
    let(:query_params) do
      { position: 'kills', elo: 'SILVER', role: 'TOP' }
    end

    before :each do
      allow(controller).to receive(:champion_params).and_return(champion_params)
    end

    it 'should rank the champions by the specified position' do
      champion_params[:position] = 'deaths'
      post action, params
      expect(speech).to eq 'The three champions with the highest deaths playing Top in Silver division are Rengar, Yasuo, and Quinn.'
    end

    it 'should sort the champions by the specified ordering' do
      champion_params[:list_order] = 'lowest'
      post action, params
      expect(speech).to eq 'The three champions with the lowest kills playing Top in Silver division are Nautilus, Galio, and Maokai.'
    end

    context 'with no champions returned' do
      let(:champion) { Champion.new(name: 'Bard') }

      context 'with normal list position' do
        before :each do
          allow(Rails.cache).to receive(:read).with(query_params).and_return([])
          allow(Rails.cache).to receive(:read).with('champions').and_call_original
        end

        context 'with complete champions returned' do
          before :each do
            champion_params[:list_size] = '0'
          end

          it 'should indicate that 0 champions were requested' do
            post action, params
            expect(speech).to eq 'No champions were requested.'
          end
        end

        context 'with incomplete champions returned' do
          it 'should indicate that there are no champions for that role and elo' do
            post action, params
            expect(speech).to eq 'There are no champions available playing Top in Silver division in the current patch.'
          end
        end
      end

      context 'with offset list position' do
        before :each do
          champion_params[:list_position] = '2'
        end

        context 'with complete champions returned' do
          before :each do
            champion_params[:list_size] = '0'
          end

          it 'should indicate that 0 champions were requested' do
            post action, params
            expect(speech).to eq 'No champions were requested.'
          end
        end

        context 'with incomplete champions returned' do
          before :each do
            allow(Rails.cache).to receive(:read).with(query_params).and_return(
              Rails.cache.read(query_params).first(1)
            )
            allow(Rails.cache).to receive(:read).with('champions').and_call_original
          end

          it 'should indicate that there are no champions for that role and elo at that position' do
            post action, params
            expect(speech).to eq 'The current patch only has data for one champion playing Top in Silver division. There are no champions beginning at the second position.'
          end
        end
      end
    end

    context 'with single champion returned' do
      context 'with normal list position' do
        before :each do
          allow(Rails.cache).to receive(:read).with(query_params).and_return(
            Rails.cache.read(query_params).first(1)
          )
          allow(Rails.cache).to receive(:read).with('champions').and_call_original
          champion_params[:list_size] = '1'
        end

        context 'with complete champions returned' do
          it 'should return the champion' do
            post action, params
            expect(speech).to eq 'The champion with the highest kills playing Top in Silver division is Talon.'
          end
        end

        context 'with incomplete champions returned' do
          before :each do
            allow(Rails.cache).to receive(:read).with(query_params).and_return([])
            allow(Rails.cache).to receive(:read).with('champions').and_call_original
          end

          it 'should indicate that there are not enough champions' do
            post action, params
            expect(speech).to eq 'There are no champions available playing Top in Silver division in the current patch.'
          end
        end
      end

      context 'with offset list position' do
        before :each do
          allow(Rails.cache).to receive(:read).with(query_params).and_return(
            Rails.cache.read(query_params).first(2)
          )
          allow(Rails.cache).to receive(:read).with('champions').and_call_original
          champion_params[:list_size] = '1'
          champion_params[:list_position] = '2'
        end

        context 'with complete champions returned' do
          it 'should return the champion' do
            post action, params
            expect(speech).to eq 'The champion with the second highest kills playing Top in Silver division is Rengar.'
          end
        end

        context 'with incomplete champions returned' do
          before :each do
            allow(Rails.cache).to receive(:read).with(query_params).and_return([])
            allow(Rails.cache).to receive(:read).with('champions').and_call_original
          end

          it 'should indicate that there are not enough champions' do
            post action, params
            expect(speech).to eq 'The current patch only has data for zero champions playing Top in Silver division. There are no champions beginning at the second position.'
          end
        end
      end
    end

    context 'with multiple champions returned' do
      before :each do
        champion_params[:list_size] = '5'
      end

      context 'with normal list position' do
        context 'with complete champions returned' do
          it 'should return the champions' do
            post action, params
            expect(speech).to eq 'The five champions with the highest kills playing Top in Silver division are Talon, Rengar, Quinn, Pantheon, and Akali.'
          end
        end

        context 'with incomplete champions returned' do
          before :each do
            allow(Rails.cache).to receive(:read).with(query_params).and_return(
              Rails.cache.read(query_params).first(3)
            )
            allow(Rails.cache).to receive(:read).with('champions').and_call_original
          end

          it 'should indicate that there are not enough champions' do
            post action, params
            expect(speech).to eq 'The current patch only has enough data for three champions. The three champions with the highest kills playing Top in Silver division are Talon, Rengar, and Quinn.'
          end
        end
      end

      context 'with offset list position' do
        before :each do
          champion_params[:list_position] = '2'
        end

        context 'with complete champions returned' do
          it 'should return the champions' do
            post action, params
            expect(speech).to eq 'The second through seventh champions with the highest kills playing Top in Silver division are Rengar, Quinn, Pantheon, Akali, and Wukong.'
          end
        end

        context 'with incomplete champions returned' do
          before :each do
            allow(Rails.cache).to receive(:read).with(query_params).and_return(
              Rails.cache.read(query_params).first(3)
            )
            allow(Rails.cache).to receive(:read).with('champions').and_call_original
          end

          it 'should indicate that there are not enough champions' do
            post action, params
            expect(speech).to eq 'The current patch only has enough data for three champions. The second through fourth champions with the highest kills playing Top in Silver division are Rengar and Quinn.'
          end
        end
      end
    end
  end

  describe 'POST stats' do
    include_context 'determinate speech'
    let(:action) { :stats }
    let(:champion_params) do
      {
        stat: 'armor',
        name: 'Nocturne',
        level: '5'
      }
    end

    before :each do
      allow(controller).to receive(:champion_params).and_return(champion_params)
    end

    context 'with a valid level' do
      it "should specify the champion's stat value at the given level" do
        post action, params
        expect(speech).to eq 'Nocturne has 40.88 armor at level 5.'
      end
    end

    context 'with an invalid level' do
      before :each do
        champion_params[:level] = '25'
      end

      it 'should respond indicating that the level is invalid' do
        post action, params
        expect(speech).to eq 'A valid champion level is between 1 and 18.'
      end
    end
  end

  describe 'POST ability_order' do
    include_context 'determinate speech'
    let(:action) { :ability_order }
    let(:champion_params) do
      {
        name: 'Azir',
        role: 'MIDDLE',
        elo: 'GOLD',
        metric: 'highestCount'
      }
    end

    before :each do
      allow(controller).to receive(:champion_params).and_return(champion_params)
    end

    it 'should indicate the ability ordering for the champion' do
      post action, params
      expect(speech).to eq 'The most frequent ability order for Azir Middle in Gold is W, Q, E, Q, Q, R, Q, W, Q, W, R, W, W, E, E, R, E, E.'
    end

    it 'should vary the ability ordering by metric' do
      champion_params[:metric] = 'highestWinrate'
      post action, params

      expect(speech).to eq 'The highest win rate ability order for Azir Middle in Gold is W, Q, E, W, Q, R, W, E, Q, Q, R, Q, W, W, E, R, E, E.'
    end
  end

  describe 'POST build' do
    include_context 'determinate speech'
    let(:action) { :build }
    let(:champion_params) do
      {
        name: 'Bard',
        role: 'SUPPORT',
        elo: 'GOLD',
        metric: 'highestCount'
      }
    end

    before :each do
      allow(controller).to receive(:champion_params).and_return(champion_params)
    end

    it 'should determine the best build for the champion' do
      post action, params
      expect(speech).to eq "The most frequent build for Bard Support in Gold division is Boots of Mobility, Eye of the Watchers, Redemption, Locket of the Iron Solari, Knight's Vow, and Mikael's Crucible."
    end

    it 'should vary the build based on the specified metric' do
      champion_params[:metric] = 'highestWinrate'
      post action, params
      expect(speech).to eq "The highest win rate build for Bard Support in Gold division is Boots of Swiftness, Eye of the Watchers, Locket of the Iron Solari, Redemption, Iceborn Gauntlet, and Rylai's Crystal Scepter."
    end
  end

  describe 'POST matchup' do
    include_context 'determinate speech'
    let(:action) { :matchup }
    let(:champion_params) do
      {
        name1: 'Shyvana',
        name2: 'Nocturne',
        role1: 'JUNGLE',
        role2: 'JUNGLE',
        elo: 'GOLD',
        matchup_position: 'kills'
      }
    end

    before :each do
      allow(controller).to receive(:champion_params).and_return(champion_params)
    end

    context 'error messages' do
      context 'duo role no matchup' do
        let(:champion_params) do
          {
            name1: 'Jinx',
            name2: 'Nocturne',
            role1: 'JUNGLE',
            role2: 'JUNGLE',
            elo: 'GOLD',
            matchup_position: 'kills'
          }
        end

        it 'should indicate that the champions do not play together' do
          post action, params
          expect(speech).to eq 'I do not have any information on matchups for Jinx Jungle and Nocturne Jungle playing together in Gold division.'
        end
      end

      context 'single role no matchup' do
        let(:champion_params) do
          {
            name1: 'Jinx',
            name2: 'Nocturne',
            role1: 'JUNGLE',
            role2: '',
            elo: 'GOLD',
            matchup_position: 'kills'
          }
        end

        it 'should indicate that the champions do not play together' do
          post action, params
          expect(speech).to eq 'I cannot find any matchup information on Jinx and Nocturne playing Jungle in Gold division.'
        end
      end

      context 'multiple shared roles' do
        let(:champion_params) do
          {
            name1: 'Jinx',
            name2: 'Bard',
            role1: '',
            role2: '',
            elo: 'GOLD',
            matchup_position: 'kills'
          }
        end

        it 'should indicate that the champions play together in multiple roles' do
          post action, params
          expect(speech).to eq 'Jinx and Bard have matchups for multiple roles in Gold division. Please specify roles for one or both champions.'
        end
      end
    end

    context 'no shared roles' do
      let(:champion_params) do
        {
          name1: 'Jinx',
          name2: 'Darius',
          role1: '',
          role2: '',
          elo: 'GOLD',
          matchup_position: 'kills'
        }
      end

      it 'should indicate that the champions do not have any shared roles' do
        post action, params
        expect(speech).to eq 'I cannot find matchup information for Jinx and Darius for any role combination in Gold division.'
      end
    end

    context 'with solo role' do
      before :each do
        champion_params[:role1] = ''
      end

      context 'with general matchup position' do
        it 'should return the matchup for the champions' do
          post action, params
          expect(speech).to eq 'Shyvana averages 6.05 kills in Jungle, lower than Nocturne who averages 7.48 kills when playing Jungle in Gold division.'
        end
      end

      context 'with winrate matchup position' do
        before :each do
          champion_params[:matchup_position] = 'winrate'
        end

        it 'should return the matchup for the champions' do
          post action, params
          expect(speech).to eq 'Shyvana averages a 50.21% win rate in Jungle, higher than Nocturne playing Jungle in Gold division.'
        end
      end
    end

    context 'with duo role' do
      context 'with general matchup position' do
        it 'should return the matchup for the champions' do
          post action, params
          expect(speech).to eq 'Shyvana and Nocturne have 6.05 and 7.48 kills respectively playing Jungle in Gold division.'
        end
      end

      context 'with winrate matchup position' do
        before :each do
          champion_params[:matchup_position] = 'winrate'
        end

        it 'should return the matchup for the champions' do
          post action, params
          expect(speech).to eq 'Shyvana has a 50.21% win rate against Nocturne playing Jungle in Gold division.'
        end
      end
    end

    context 'with synergy role' do
      before :each do
        champion_params[:name1] = 'Bard'
        champion_params[:name2] = 'Jinx'
        champion_params[:role1] = 'SYNERGY'
      end

      context 'with general matchup position' do
        it 'should return the matchup for the champions' do
          post action, params
          expect(speech).to eq 'Bard averages 3.29 kills in Support when playing with Jinx Adc in Gold.'
        end
      end

      context 'with winrate matchup position' do
        before :each do
          champion_params[:matchup_position] = 'winrate'
        end

        it 'should return the matchup for the champions' do
          post action, params
          expect(speech).to eq 'Bard averages a 50.83% win rate in Support when playing alongside Jinx Adc in Gold.'
        end
      end
    end
  end

  describe 'POST matchup_ranking' do
    include_context 'determinate speech'
    let(:action) { :matchup_ranking }
    let(:champion_params) do
      {
        name: 'Shyvana',
        role1: 'JUNGLE',
        role2: 'JUNGLE',
        elo: 'GOLD',
        list_order: 'highest',
        list_position: '1',
        list_size: '1',
        matchup_position: 'winrate'
      }
    end
    let(:query_params) do
      { matchups: { name: 'Shyvana', role: 'JUNGLE', elo: 'GOLD' } }
    end

    before :each do
      allow(controller).to receive(:champion_params).and_return(champion_params)
    end

    context 'with both roles specified' do
      context 'with both roles the same' do
        it 'should return the matchups for that role combination' do
          post action, params
          expect(speech).to eq "The champion with the highest win rate playing Jungle against Shyvana from Gold division is Cho'Gath."
        end
      end

      context 'with either role synergy' do
        before :each do
          champion_params[:role1] = 'SYNERGY'
          champion_params[:name] = 'Sivir'
        end
        it 'should return the matchups for the synergy role' do
          post action, params
          expect(speech).to eq 'The champion with the highest win rate playing Support with Sivir Adc from Gold division is Sion.'
        end
      end

      context 'with one role ADC and one SUPPORT' do
        before :each do
          champion_params[:role1] = 'ADC'
          champion_params[:role2] = 'SUPPORT'
          champion_params[:name] = 'Jhin'
        end
        it 'should return the matchups for the synergy role' do
          post action, params
          expect(speech).to eq 'The champion with the highest win rate playing Support against Jhin Adc from Gold division is Taric.'
        end
      end
    end

    context 'with no role specified' do
      before :each do
        champion_params[:role1] = ''
        champion_params[:role2] = ''
      end

      context 'with only one role played by the champion' do
        it 'should return the complete list of champions' do
          post action, params
          expect(speech).to eq "The champion with the highest win rate playing Jungle against Shyvana from Gold division is Cho'Gath."
        end
      end
    end

    context 'with only the named role specified' do
      before :each do
        champion_params[:role1] = 'JUNGLE'
        champion_params[:role2] = ''
      end

      it 'should use the named role to find the matchups' do
        post action, params
        expect(speech).to eq "The champion with the highest win rate playing Jungle against Shyvana from Gold division is Cho'Gath."
      end
    end

    context 'with only the unnamed role specified' do
      before :each do
        champion_params[:role1] = ''
      end

      context 'as a non-adc/support role' do
        it 'should use the unnamed role and return the complete list of champions' do
          post action, params
          expect(speech).to eq "The champion with the highest win rate playing Jungle against Shyvana from Gold division is Cho'Gath."
        end
      end

      context 'as a support role' do
        before :each do
          champion_params[:role1] = ''
          champion_params[:role2] = 'SUPPORT'
        end

        it 'should use the unnamed role to determine if the named champion is an ADC' do
          champion_params[:name] = 'Jinx'
          post action, params
          expect(speech).to eq 'The champion with the highest win rate playing Support against Jinx from Gold division is Janna.'
        end

        it 'should use the unnamed role to determine if the named champion is a Support' do
          champion_params[:name] = 'Janna'
          post action, params
          expect(speech).to eq 'The champion with the highest win rate playing Support against Janna from Gold division is Sona.'
        end
      end

      context 'as an ADC role' do
        before :each do
          champion_params[:role1] = ''
          champion_params[:role2] = 'ADC'
        end

        it 'should use the unnamed role to determine if the named champion is an ADC' do
          champion_params[:name] = 'Jinx'
          post action, params
          expect(speech).to eq 'The champion with the highest win rate playing Adc against Jinx from Gold division is Miss Fortune.'
        end

        it 'should use the unnamed role to determine if the named champion is a Support' do
          champion_params[:name] = 'Janna'
          post action, params
          expect(speech).to eq 'The champion with the highest win rate playing Adc against Janna from Gold division is Miss Fortune.'
        end
      end
    end

    context 'error messages' do
      context 'duo roles empty matchup rankings' do
        before :each do
          champion_params[:role1] = 'TOP'
          champion_params[:role2] = 'MIDDLE'
        end

        it 'should indicate that the champion has no matchup rankings for the given two roles' do
          post action, params
          expect(speech).to eq 'There are no matchup rankings for champions playing Middle with Shyvana Top in Gold division.'
        end
      end

      context 'named role' do
        before :each do
          champion_params[:role2] = ''
        end

        context 'empty matchup rankings' do
          before :each do
            allow(Rails.cache).to receive(:read).and_return(nil)
          end

          it 'should indicate that the champion has no matchup rankings for the given role' do
            post action, params
            expect(speech).to eq 'There are no matchup rankings for Shyvana Jungle.'
          end
        end
      end

      context 'unnamed role' do
        before :each do
          champion_params[:role1] = ''
        end

        context 'empty matchup rankings' do
          before :each do
            allow(Rails.cache).to receive(:read).and_return(nil)
          end

          it 'should indicate that there are no matchup rankings for the unnamed role' do
            post action, params
            expect(speech).to eq 'There are no matchup rankings for champions playing Jungle with Shyvana.'
          end
        end
      end

      context 'empty roles' do
        before :each do
          champion_params[:role1] = ''
          champion_params[:role2] = ''
        end

        context 'with multiple matchup rankings' do
          before :each do
            champion_params[:name] = 'Jinx'
          end

          it 'should ask for role specification' do
            post action, params
            expect(speech).to eq "There are multiple matchup rankings for Jinx, please specify Jinx's role."
          end
        end

        context 'with empty matchup rankings' do
          before :each do
            allow(Rails.cache).to receive(:read).and_return(nil)
          end

          it 'should indicate the champion has no rankings' do
            post action, params
            expect(speech).to eq 'There are no matchup rankings for Shyvana.'
          end
        end
      end
    end

    context 'api responses' do
      context 'no champions returned' do
        context 'with normal position' do
          context 'with complete matchup rankings' do
            before :each do
              champion_params[:list_size] = '0'
            end

            it 'should indicate that no champions were requested' do
              post action, params
              expect(speech).to eq 'No champions were requested.'
            end
          end
        end
        
        context 'with offset position' do
          before :each do
            champion_params[:list_position] = '2'
          end

          context 'with complete matchup rankings' do
            before :each do
              champion_params[:list_size] = '0'
            end

            it 'should indicate that there were no champions requested' do
              post action, params
              expect(speech).to eq 'No champions were requested.'
            end
          end

          context 'with incomplete matchup rankings' do
            before :each do
              allow(Rails.cache).to receive(:read).with(query_params).and_return(
                Rails.cache.read(query_params).first(1)
              )
            end

            it 'should indicate that there are not enough champions when begun at that offset' do
              post action, params
              expect(speech).to eq 'The current patch only has data for one champion playing Jungle in Gold division. There are no champions beginning at the second position.'
            end
          end
        end
      end

      context 'with a single champion returned' do
        context 'with normal list position' do
          context 'with complete matchup rankings' do
            context 'with a shared role' do
              it 'should return the complete list of champions, specifying one role' do
                post action, params
                expect(speech).to eq "The champion with the highest win rate playing Jungle against Shyvana from Gold division is Cho'Gath."
              end
            end

            context 'with duo roles' do
              before :each do
                champion_params[:name] = 'Janna'
                champion_params[:role1] = 'SUPPORT'
                champion_params[:role2] = 'ADC'
              end

              it 'should return the complete list of champions, specifying both roles' do
                post action, params
                expect(speech).to eq 'The champion with the highest win rate playing Adc against Janna Support from Gold division is Miss Fortune.'
              end
            end

            context 'with synergy' do
              before :each do
                champion_params[:name] = 'Janna'
                champion_params[:role1] = 'SYNERGY'
                champion_params[:role2] = 'ADC'
              end

              it 'should return the complete list of champions, specifying that it is a synergy ranking' do
                post action, params
                expect(speech).to eq 'The champion with the highest win rate playing Adc with Janna Support from Gold division is Twitch.'
              end
            end
          end

          context 'with incomplete matchup rankings' do
            before :each do
              allow(Rails.cache).to receive(:read).with(query_params).and_return(
                Rails.cache.read(query_params).first(1)
              )
              champion_params[:list_size] = 2
            end

            it 'should return the partial list of champions, indicating that there are not enough' do
              post action, params
              expect(speech).to eq 'The current patch only has enough data for a single champion. The single champion with the highest win rate playing Jungle against Shyvana from Gold division is Lee Sin.'
            end
          end
        end

        context 'with offset list position' do
          before :each do
            champion_params[:list_position] = '2'
          end

          context 'with complete matchup rankings' do
            context 'with a shared role' do
              it 'should return the complete list of champions, indicating the offset and one role' do
                post action, params
                expect(speech).to eq 'The champion with the second highest win rate playing Jungle against Shyvana from Gold division is Kindred.'
              end
            end

            context 'with duo roles' do
              before :each do
                champion_params[:name] = 'Jinx'
                champion_params[:role1] = 'ADC'
                champion_params[:role2] = 'SUPPORT'
              end

              it 'should return the complete list of champions, indicating the offset and both roles' do
                post action, params
                expect(speech).to eq 'The champion with the second highest win rate playing Support against Jinx Adc from Gold division is Sion.'
              end
            end

            context 'with synergy role' do
              before :each do
                champion_params[:name] = 'Jinx'
                champion_params[:role1] = 'SYNERGY'
                champion_params[:role2] = 'SUPPORT'
              end

              it 'should return the complete list of champions, indicating the offset and specifying that it is a synergy role' do
                post action, params
                expect(speech).to eq 'The champion with the second highest win rate playing Support with Jinx Adc from Gold division is Sion.'
              end
            end
          end

          context 'with incomplete matchup rankings' do
            before :each do
              champion_params[:list_size] = '2'
            end

            before :each do
              allow(Rails.cache).to receive(:read).with(query_params).and_return(
                Rails.cache.read(query_params).first(2)
              )
            end

            it 'should return the incomplete list of champions, indicating the offset position' do
              post action, params
              expect(speech).to eq 'The current patch only has enough data for a single champion beginning at the second position. The single champion with the highest win rate playing Jungle against Shyvana from Gold division is Kayn.'
            end
          end
        end
      end

      context 'with multiple champions returned' do
        before :each do
          champion_params[:list_size] = '3'
        end

        context 'with normal list position' do
          context 'with complete matchup rankings' do
            context 'with a shared role' do
              it 'should return the complete list of champions, indicating the one shared role' do
                post action, params
                expect(speech).to eq "The champions with the highest win rate playing Jungle against Shyvana from Gold division are Cho'Gath, Kindred, and Nunu."
              end
            end

            context 'with duo roles' do
              before :each do
                champion_params[:role1] = 'ADC'
                champion_params[:role2] = 'SUPPORT'
                champion_params[:name] = 'Jinx'
              end

              it 'should return the complete list of champions, indicating the two roles' do
                post action, params
                expect(speech).to eq 'The champions with the highest win rate playing Support against Jinx Adc from Gold division are Janna, Sion, and Trundle.'
              end
            end

            context 'with synergy role' do
              before :each do
                champion_params[:role1] = 'ADC'
                champion_params[:role2] = 'SYNERGY'
                champion_params[:name] = 'Jinx'
              end

              it 'should return the complete list of champions, indicating they synergize' do
                post action, params
                expect(speech).to eq 'The champions with the highest win rate playing Support with Jinx Adc from Gold division are Poppy, Sion, and Janna.'
              end
            end
          end

          context 'with incomplete matchup rankings' do
            before :each do
              allow(Rails.cache).to receive(:read).with(query_params).and_return(
                Rails.cache.read(query_params).first(2)
              )
              allow(Rails.cache).to receive(:read).with(:champions).and_call_original
              allow(Rails.cache).to receive(:read).with('champions').and_call_original
              champion_params[:list_size] = 3
            end

            context 'with a shared role' do
              it 'should return the partial list of champions, indicating the one shared role' do
                post action, params
                expect(speech).to eq 'The current patch only has enough data for two champions. The two champions with the highest win rate playing Jungle against Shyvana from Gold division are Lee Sin and Kayn.'
              end
            end

            context 'with duo roles' do
              let(:query_params) do
                { matchups: { name: 'Jinx', role: 'ADCSUPPORT', elo: 'GOLD' } }
              end
              before :each do
                champion_params[:role1] = 'ADC'
                champion_params[:role2] = 'SUPPORT'
                champion_params[:name] = 'Jinx'
              end

              it 'should return the partial list of champions, indicating the multiple roles' do
                post action, params
                expect(speech).to eq 'The current patch only has enough data for two champions. The two champions with the highest win rate playing Support against Jinx Adc from Gold division are Blitzcrank and Thresh.'
              end
            end

            context 'with synergy role' do
              let(:query_params) do
                { matchups: { name: 'Jinx', role: 'SYNERGY', elo: 'GOLD' } }
              end
              before :each do
                champion_params[:role1] = 'ADC'
                champion_params[:role2] = 'SYNERGY'
                champion_params[:name] = 'Jinx'
              end

              it 'should return the partial list of champions, indicating the synergy role' do
                post action, params
                expect(speech).to eq 'The current patch only has enough data for two champions. The two champions with the highest win rate playing Support with Jinx Adc from Gold division are Blitzcrank and Thresh.'
              end
            end
          end

          context 'with offset list position' do
            before :each do
              champion_params[:list_position] = '2'
              champion_params[:list_size] = '4'
            end

            context 'with complete matchup rankings' do
              context 'with a shared role' do
                it 'should return the complete list of champions, specifying the offset and shared role' do
                  post action, params
                  expect(speech).to eq 'The second through fifth champions with the highest win rate playing Jungle against Shyvana from Gold division are Kindred, Nunu, Rammus, and Jax.'
                end
              end

              context 'with duo roles' do
                before :each do
                  champion_params[:name] = 'Janna'
                  champion_params[:role1] = 'SUPPORT'
                  champion_params[:role2] = 'ADC'
                end

                it 'should return the complete list of champions, specifying the offset and duo roles' do
                  post action, params
                  expect(speech).to eq 'The second through fifth champions with the highest win rate playing Adc against Janna Support from Gold division are Twitch, Tristana, Draven, and Jhin.'
                end
              end

              context 'with synergy role' do
                before :each do
                  champion_params[:name] = 'Janna'
                  champion_params[:role1] = 'SYNERGY'
                  champion_params[:role2] = 'ADC'
                end

                it 'should return the complete list of champions, specifying the offset and synergy role' do
                  post action, params
                  expect(speech).to eq 'The second through fifth champions with the highest win rate playing Adc with Janna Support from Gold division are Miss Fortune, Jinx, Tristana, and Draven.'
                end
              end
            end

            context 'with incomplete matchup rankings' do
              before :each do
                allow(Rails.cache).to receive(:read).with(query_params).and_return(
                  Rails.cache.read(query_params).first(3)
                )
                allow(Rails.cache).to receive(:read).with(:champions).and_call_original
                allow(Rails.cache).to receive(:read).with('champions').and_call_original
              end
              context 'with a shared role' do
                it 'should return the partial list of champions, specifying the offset and shared role' do
                  post action, params
                  expect(speech).to eq 'The current patch only has enough data for three champions. The second through third champions with the highest win rate playing Jungle against Shyvana from Gold division are Lee Sin and Kayn.'
                end
              end

              context 'with duo roles' do
                let(:query_params) do
                  { matchups: { name: 'Jinx', role: 'ADCSUPPORT', elo: 'GOLD' } }
                end
                before :each do
                  champion_params[:role1] = 'ADC'
                  champion_params[:role2] = 'SUPPORT'
                  champion_params[:name] = 'Jinx'
                end

                it 'should return the partial list of champions, specifying the offset and duo roles' do
                  post action, params
                  expect(speech).to eq 'The current patch only has enough data for three champions. The second through third champions with the highest win rate playing Support against Jinx Adc from Gold division are Blitzcrank and Thresh.'
                end
              end

              context 'with synergy role' do
                let(:query_params) do
                  { matchups: { name: 'Jinx', role: 'SYNERGY', elo: 'GOLD' } }
                end
                before :each do
                  champion_params[:role1] = 'ADC'
                  champion_params[:role2] = 'SYNERGY'
                  champion_params[:name] = 'Jinx'
                end

                it 'should return the partial list of champions, specifying the offset and synergy role' do
                  post action, params
                  expect(speech).to eq 'The current patch only has enough data for three champions. The second through third champions with the highest win rate playing Support with Jinx Adc from Gold division are Thresh and Lulu.'
                end
              end
            end
          end
        end
      end
    end
  end

  describe 'POST title' do
    let(:action) { :title }
    let(:response_text) { "Sona's title is Maven of the Strings." }

    it 'should return the champions title' do
      post action, params
      expect(speech).to eq response_text
    end
  end

  describe 'POST stats' do
    let(:action) { :stats }
    let(:response_text) { 'Zed has 68 attack damage at level 5.' }

    context 'with stat modifier' do
      context 'with level specified' do
        it 'should calculate the stat for the champion' do
          post action, params
          expect(speech).to eq response_text
        end
      end

      context 'without level specified' do
        before :each do
          allow(controller).to receive(:champion_params).and_return(
            champion: 'Zed',
            stat: 'attackdamage'
          )
        end

        it 'should ask for the level' do
          post action, params
          expect(speech).to eq controller.send(:ask_for_level_response)[:speech]
        end
      end
    end

    context 'without stat modifier' do
      let(:response_text) { 'Zed has 345 movement speed.' }
      before :each do
        allow(controller).to receive(:champion_params).and_return(
          champion: 'Zed',
          stat: 'movespeed'
        )
      end

      it 'should calculate the stat for the champion' do
        post action, params
        expect(speech).to eq response_text
      end
    end
  end

  describe 'POST build' do
    let(:action) { :build }
    let(:response_text) {
      "The highest win rate build for Bard Support is Boots of Mobility, Sightstone, Frost Queen's Claim, Redemption, Knight's Vow, and Locket of the Iron Solari."
    }

    it 'should provide a build for a champion' do
      post action, params
      expect(speech).to eq response_text
    end
  end

  describe 'POST ability_order' do
    let(:action) { :ability_order }
    let(:response_text) {
      "The highest win rate on Azir Middle has you start W, Q, Q, E and then max Q, W, E."
    }

    context 'with repeated 3 starting abililties' do
      it 'should return the 4 first order and max order for abilities' do
        post action, params
        expect(speech).to eq response_text
      end
    end

    context 'with uniq starting 3 abilities' do
      let(:response_text) {
        "The highest win rate on Azir Middle has you start W, Q, E and then max Q, W, E."
      }

      it 'should return the 3 first order and max order for abilities' do
        champion = Champion.new(name: 'Azir')
        order = champion.roles.first[:skills][:highestWinPercent][:order]
        order[2] = 'E'
        order[3] = 'Q'
        allow(Champion).to receive(:new).and_return(champion)
        post action, params
        expect(speech).to eq response_text
      end
    end
  end

  describe 'POST counters' do
    let(:action) { :counters }
    let(:response_text) {
      "The best counter for Jayce Top is Jarvan IV at a 58.19% win rate."
    }

    context 'without enough matchups' do
      let(:champion) { Champion.new(name: 'Bard') }
      let(:role_data) do
        champion.roles.first.tap do |role|
          role[:matchups] = role[:matchups].select do |matchup|
            matchup[:games] >= 100
          end.first(2)
        end
      end

      before :each do
        allow(controller).to receive(:champion_params).and_return(
          champion: champion.name,
          list_size: 10
        )
        allow(Champion).to receive(:new).and_return(champion)
        allow(champion).to receive(:find_by_role).and_return(role_data)
      end

      it 'should indicate that there was not the correct number of results' do
        post action, params
        expect(speech).to eq 'The current patch only has enough data for two counters. The best two counters for Bard Support are Zilean at a 57.75% win rate and Taric at a 57.9% win rate.'
      end
    end

    context 'without any matchups' do
      let(:champion) { Champion.new(name: 'Bard') }
      let(:role_data) do
        champion.roles.first.tap do |role|
          role[:matchups].map! { |_| { games: 10 } }
        end
      end

      before :each do
        allow(controller).to receive(:champion_params).and_return({
          champion: champion.name
        })
        allow(Champion).to receive(:new).and_return(champion)
        allow(champion).to receive(:find_by_role).and_return(role_data)
      end

      it 'should specify that there is not enough data in the current patch' do
        post action, params
        expect(speech).to eq 'There is not enough data for Bard in the current patch.'
      end
    end

    context 'with worst order' do
      let(:response_text) {
        "The worst four counters for Jayce Top are Singed at a 43.12% win rate, Dr. Mundo at a 44.37% win rate, Teemo at a 47.78% win rate, and Garen at a 47.8% win rate."
      }
      before :each do
        allow(controller).to receive(:champion_params).and_return(
          list_size: '4',
          lane: 'Top',
          list_position: '1',
          list_order: 'worst',
          champion: 'Jayce'
        )
      end

      it 'should return the worst counters for the champion' do
        post action, params
        expect(speech).to eq response_text
      end
    end

    context 'with list position' do
      let(:response_text) {
        "The second best counter for Jayce Top is Sion at a 56.3% win rate."
      }
      before :each do
        allow(controller).to receive(:champion_params).and_return(
          list_size: '1',
          lane: 'Top',
          list_position: '2',
          list_order: 'best',
          champion: 'Jayce'
        )
      end

      it 'should return the champion at that list position for the champion' do
        post action, params
        expect(speech).to eq response_text
      end
    end

    it 'should return the best counters for the champion' do
      post action, params
      expect(speech).to eq response_text
    end
  end

  describe 'POST lane' do
    let(:action) { :lane }
    let(:response_text) {
      "Jax got better in the last patch and is currently ranked forty-first out of fifty-seven with a 49.69% win rate and a 3.76% play rate as Top."
    }

    it 'should indicate the strength of champions in the given lane' do
      post action, params
      expect(speech).to eq(response_text)
    end
  end

  describe 'POST ability' do
    let(:action) { :ability }
    let(:response_text) {
      "Ivern's second ability is called Brushmaker. In brush, Ivern's attacks are ranged and deal bonus magic damage. Ivern can activate this ability to create a patch of brush."
    }

    it "should describe the champion's ability" do
      post action, params

      expect(speech).to eq response_text
    end
  end

  describe 'POST cooldown' do
    let(:action) { :cooldown }
    let(:response_text) {
      "Yasuo's fourth ability, Last Breath, has a cooldown of 0 seconds at rank 3."
    }

    it "should provide the champion's cooldown" do
      post action, params
      expect(speech).to eq response_text
    end
  end

  describe 'POST description' do
    let(:action) { :description }
    let(:response_text) {
      "Katarina, the the Sinister Blade, is an Assassin and a Mage and is played as Middle."
    }

    it 'should provide a description for the champion' do
      post action, params
      expect(speech).to eq response_text
    end
  end

  describe 'POST ally_tips' do
    let(:action) { :ally_tips }
    let(:response_text) {
      "Here's a tip for playing as Fiora: Grand Challenge allows Fiora to take down even the most durable opponents and then recover if successful, so do not hesitate to attack the enemy's front line."
    }

    it 'should provide tips for playing the champion' do
      champion = Champion.new(name: 'Fiora')
      allow(Champion).to receive(:new).and_return(champion)
      allow(champion.allytips).to receive(:sample).and_return(
        champion.allytips.last
      )

      post action, params
      expect(speech).to eq response_text
    end
  end

  describe 'POST enemy_tips' do
    let(:action) { :enemy_tips }
    let(:response_text) {
      "Here's a tip for playing against LeBlanc: Stunning or silencing LeBlanc will prevent her from activating the return part of Distortion."
    }

    it 'should provide tips for beating the enemy champion' do
      champion = Champion.new(name: 'Leblanc')
      allow(Champion).to receive(:new).and_return(champion)
      allow(champion.enemytips).to receive(:sample).and_return(
        champion.enemytips.last
      )

      post action, params
      expect(speech).to eq response_text
    end
  end
end
