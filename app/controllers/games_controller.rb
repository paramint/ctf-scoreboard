# frozen_string_literal: true

require 'zip'

class GamesController < ApplicationController
  include ApplicationModule

  before_action :load_game, only: %i[terms_of_service privacy_notice]

  before_action only: %i[completion_certificate_template] do
    load_game(:users)
    deny_if_not_admin
  end
  before_action only: %i[summary] do
    load_game(divisions: :teams)
    load_users_and_divisions
    load_game_graph_data
  end
  before_action only: %i[show] do
    deny_users_to_non_html_formats
    load_game(
      :categories, :teams,
      { standard_challenges: :solved_challenges },
      { pentest_challenges: :solved_challenges },
      flags: { solved_challenges: :team }
    )
  end
  before_action :filter_access_before_game_open
  before_action :load_message_count

  def terms_of_service; end

  def privacy_notice; end

  def show
    prepare_pentest_challenge_table # Always show PentestChallenges, no matter the Gameboard type
    prepare_standard_challenge_table
    respond_to do |format|
      format.html
      format.markdown do
        render_to_string :show
      end
    end
  end

  def summary
    respond_to do |format|
      format.html
      format.json { render json: { standings: @game.all_teams_information } }
    end
  end

  def completion_certificate_template
    download_file(@game.completion_certificate_template, @game.title)
  end

  def load_users_and_divisions
    @divisions = @game.divisions
    signed_in_not_admin = !current_user&.admin?
    @active_division = signed_in_not_admin && current_user&.team ? current_user&.team&.division : @divisions.first
  end

  def load_game_graph_data
    @group_method = @game.graph_group_method
    @flags_per_hour = SubmittedFlag.group_by_period(@group_method, :created_at).count
    prepare_line_chart_data
  end

  def prepare_line_chart_data
    @line_chart_data = [
      {
        name: I18n.t('game.summary.flag_submissions_graph.flags_submitted'), data: @flags_per_hour
      },
      {
        name: I18n.t('game.summary.flag_submissions_graph.challenges_solved'),
        data: FeedItem.solved_challenges.group_by_period(@group_method, :created_at).count
      }
    ]
  end

  def deny_users_to_non_html_formats
    deny_if_not_admin unless request.format.html?
  end

  private

  def prepare_standard_challenge_table
    # What information we need depends on the game mode we are in, however
    # we will always need a list of challenges
    if @game.jeopardy? || @game.title_and_description?
      prepare_jeopardy_or_title_and_description_board
    else
      @standard_challenges = @game&.standard_challenges
      ActiveRecord::Precounter.new(@standard_challenges).precount(:solved_challenges)
      prepare_teams_x_challenges_table if @game.teams_x_challenges?
    end
  end

  def prepare_teams_x_challenges_table
    @headings = [
      Struct.new(:name).new(I18n.t('game.summary.challenge_table.teams_header')), @standard_challenges
    ].flatten
    @teams = @game&.teams
  end

  def prepare_jeopardy_or_title_and_description_board
    @standard_challenges = @game&.categories_with_standard_challenges
    @categories = @game.categories
    @category_ids = @standard_challenges.keys
  end

  def prepare_pentest_challenge_table
    @pentest_challenges = @game&.pentest_challenges
    ActiveRecord::Precounter.new(@pentest_challenges).precount(:solved_challenges)
    @pentest_table_heading = [
      Struct.new(:name).new(I18n.t('game.summary.challenge_table.teams_header')), @game&.pentest_challenges
    ].flatten
    @teams_with_assoc = @game.teams_associated_with_flags_and_pentest_challenges
  end
end
