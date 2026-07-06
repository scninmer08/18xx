# frozen_string_literal: true

# backtick_javascript: true

require 'view/game/actionable'

module View
  module Game
    class BotControls < Snabberb::Component
      include Actionable

      MAX_ACTIONS_PER_CLICK = 200

      def render
        return h(:div) unless enabled?

        bot_turn = bot_controlling?(current_controller)
        schedule_run if bot_turn && auto_run_bots? && !bot_auto_paused? && !@game.finished

        text = bot_turn ? 'Run Bots' : 'Waiting for your action'
        h('div.margined', [
          h(:button, {
              attrs: { disabled: !bot_turn || @game.finished || bot_auto_paused? },
              on: { click: -> { run_bots } },
            }, text),
          render_pause_button(bot_turn),
          h(:span, { style: { marginLeft: '0.5rem' } }, status_text(bot_turn)),
        ])
      end

      private

      def enabled?
        @game_data[:mode] == :hotseat &&
          @game.class.title == '18IL' &&
          bot_player_ids.any?
      end

      def bot_player_ids
        Array(setting_value(:bot_player_ids)).map(&:to_s)
      end

      def bot_personalities
        setting_value(:bot_personalities) || {}
      end

      def auto_run_bots?
        [true, 'true'].include?(setting_value(:bot_auto_run))
      end

      def bot_auto_paused?
        [true, 'true'].include?(setting_value(:bot_auto_paused))
      end

      def bot_action_delay
        value = setting_value(:bot_action_delay)
        return 1.5 if value.nil? || value.to_s.empty?

        seconds = value.to_f
        return 0 if seconds.negative?

        seconds > 60 ? 60 : seconds
      end

      def bot_delay_ms
        (bot_action_delay * 1000).to_i
      end

      def setting_value(key)
        settings = settings_hash
        settings[key.to_s] || settings[key]
      end

      def settings_hash
        @game_data['settings'] || @game_data[:settings] || {}
      end

      def current_controller(game = @game)
        entity = game.round.current_entity
        seen = {}
        until !entity || entity.player? || seen[entity]
          seen[entity] = true
          entity = entity.owner
        end
        entity
      end

      def bot_controlling?(player)
        player && bot_player_ids.include?(player.id.to_s)
      end

      def status_text(bot_turn)
        return 'Game over' if @game.finished
        return "Bot auto-run paused; #{current_controller&.name || 'bot'} may act manually" if bot_turn && bot_auto_paused?

        if bot_turn
          mode = auto_run_bots? ? 'auto-running' : 'ready'
          return "Bots control seats #{bot_player_ids.join(', ')} (#{mode}, #{bot_action_delay}s delay)"
        end

        player = current_controller
        player ? "#{player.name} may act" : 'Human input is required'
      end

      def render_pause_button(bot_turn)
        return h(:span) unless auto_run_bots?

        if bot_auto_paused?
          h(:button, {
              attrs: { disabled: @game.finished },
              style: { marginLeft: '0.5rem' },
              on: { click: -> { resume_bots } },
            }, 'Resume Bots')
        else
          h(:button, {
              attrs: { disabled: @game.finished || !bot_turn },
              style: { marginLeft: '0.5rem' },
              on: { click: -> { pause_bots } },
            }, 'Pause Bots')
        end
      end

      def pause_bots
        update_bot_auto_paused(true)
      end

      def resume_bots
        update_bot_auto_paused(false)
        schedule_run if bot_controlling?(current_controller) && auto_run_bots? && !@game.finished
      end

      def update_bot_auto_paused(paused)
        settings = settings_hash
        settings[:bot_auto_paused] = paused
        settings['bot_auto_paused'] = paused if settings.key?('bot_auto_paused')

        @game_data[:settings] = settings if !@game_data.key?(:settings) && !@game_data.key?('settings')
        Lib::Storage[@game_data[:id]] = @game_data
        store(:game_data, @game_data, skip: true)
        store(:game, @game)
      end

      def run_bots
        @bot_actions_taken = 0
        run_next_bot_action(true)
      end

      def run_next_bot_action(continue_running = auto_run_bots?, expected_action_count = nil)
        return unless enabled?
        return if expected_action_count && @game_data[:actions].size != expected_action_count

        game = @game
        return if game.finished || bot_auto_paused? || !bot_controlling?(current_controller(game))

        @bot_actions_taken ||= 0
        if @bot_actions_taken >= MAX_ACTIONS_PER_CLICK
          return store(:flash_opts, "Bots paused after #{MAX_ACTIONS_PER_CLICK} actions; click Run Bots to continue")
        end

        game = process_bot_action(game)
        return unless game

        @bot_actions_taken += 1
        schedule_run(continue_running) if continue_running && !game.finished && bot_controlling?(current_controller(game))
      end

      def schedule_run(continue_running = auto_run_bots?)
        return if bot_auto_paused?

        expected_action_count = @game_data[:actions].size
        key = "#{@game.id}-#{expected_action_count}"
        already_scheduled = `window._18il_bot_hotseat_timers && window._18il_bot_hotseat_timers[#{key}]`
        return if already_scheduled

        delay = bot_delay_ms
        %x{
          window._18il_bot_hotseat_timers = window._18il_bot_hotseat_timers || {};
          window._18il_bot_hotseat_timers[#{key}] = true;
          var component = #{self};
          window.setTimeout(function() {
            delete window._18il_bot_hotseat_timers[#{key}];
            component.$run_next_bot_action(#{continue_running}, #{expected_action_count});
          }, #{delay});
        }
      end

      def process_bot_action(game)
        player = current_controller(game)
        policy = policy_for(game, player)

        decision = policy.choose(game)
        unless decision.action
          store(:flash_opts, "Bot stopped: #{decision.reason}")
          return nil
        end

        game = game.process_action(decision.action, add_auto_actions: true).maybe_raise!
        @game_data[:actions] << decision.action.to_h
        update_game_data(game)

        game
      rescue StandardError => e
        LOGGER.error(e)
        store(:flash_opts, "Bot stopped: #{e.message}")
        nil
      end

      def policy_for(game, player)
        @bot_policies = {} if @bot_policy_game_id != game.id
        @bot_policy_game_id = game.id
        key = bot_personality_key(player)
        @bot_policies ||= {}
        @bot_policies[[player&.id, key]] ||= Engine::Game::G18IL::Bot::BaselinePolicy.new(
          profile: Engine::Game::G18IL::Bot::PolicyProfile.personality(key),
        )
      end

      def bot_personality_key(player)
        personalities = bot_personalities
        key = personalities[player&.id.to_s] || personalities[player&.id] || player&.name
        Engine::Game::G18IL::Bot::PolicyProfile.normalize_personality_key(key)
      end

      def update_game_data(game)
        @game_data[:turn] = game.turn
        @game_data[:round] = game.round.name
        @game_data[:acting] = game.active_players_id
        @game_data[:updated_at] = Time.now.to_i
        if game.finished
          @game_data[:result] = game.result
          @game_data[:status] = 'finished'
          @game_data[:manually_ended] = game.manually_ended
          @game_data[:game_end_reason] = game.game_end_reason
        else
          @game_data[:result] = {}
          @game_data[:status] = 'active'
          @game_data[:manually_ended] = nil
          @game_data[:game_end_reason] = nil
        end

        Lib::Storage[@game_data[:id]] = @game_data
        store(:game_data, @game_data, skip: true)
        @game = game
        store(:game, game)
      end
    end
  end
end
