ENV["RACK_ENV"] = "test"

require "minitest/autorun"
require "rack/test"

require_relative "../juggernaut"

class JuggernautTest < Minitest::Test
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def session
    last_request.env["rack.session"]
  end

  def teardown
    session.delete(:lifts)
  end

  def user_session
    { "rack.session" => {
      lifts: {
        bench_press: { training_max: 245.6788 },
        squat: { training_max: 340.2792 },
        deadlift: { training_max: 429.5744 },
        press: { training_max: 158.5904 }
      }
    } }
  end

  def projected_max_lifts
    {
      bench_press_weight: "185",
      bench_press_reps: "16",
      squat_weight: "255",
      squat_reps: "13",
      deadlift_weight: "322.5",
      deadlift_reps: "14",
      press_weight: "120",
      press_reps: "14"
    }
  end

  def training_max_lifts
    {
      bench_press_training_max: "245.6788",
      squat_training_max: "340.2792",
      deadlift_training_max: "429.5744",
      press_training_max: "158.5904"
    }
  end

  def projected_max_missing_lifts
    {
      bench_press_weight: "185",
      bench_press_reps: "16",
      squat_weight: "",
      squat_reps: "",
      deadlift_weight: "322.5",
      deadlift_reps: "14",
      press_weight: "120",
      press_reps: "14"
    }
  end

  def training_max_missing_lifts
    {
      bench_press_training_max: "245.6788",
      squat_training_max: "",
      deadlift_training_max: "429.5744",
      press_training_max: "158.5904"
    }
  end

  def increase_max_lifts
    projected_max_lifts.merge(wave: "10")
  end

  def increase_max_missing_lifts
    projected_max_missing_lifts.merge(wave: "10")
  end

  def bench_press
    session[:lifts][:bench_press]
  end

  def test_index_no_lifts
    get "/"

    assert_equal 200, last_response.status
    assert_includes last_response.body, %(<a href="/lifts/unknown")
    assert_includes last_response.body, %(<a href="/lifts/unknown")
  end

  def test_index_lifts_entered
    get "/", {}, user_session

    assert_equal 200, last_response.status
    assert_includes last_response.body, "<th>Projected Max</th>"
    assert_includes last_response.body, "<th>Training Max</th>"
    assert_includes last_response.body, %(<a href="/lifts/increase")
  end

  def test_view_unknown_lift_insertion
    get "/lifts/unknown"

    assert_equal 200, last_response.status
    assert_includes last_response.body, %(<form action="/lifts/unknown")

    lifts_list.each do |lift|
      %w(weight reps).each do |param|
        assert_includes last_response.body, %(name="#{lift}_#{param}")
      end
    end
  end

  def test_view_known_lift_insertion
    get "/lifts/known"

    assert_equal 200, last_response.status
    assert_includes last_response.body, %(<form action="/lifts/known")

    lifts_list.each do |lift|
      assert_includes last_response.body, %(name="#{lift}_training_max")
    end
  end

  def test_view_unknown_lift_insertion_with_exisiting_lifts
    get "/lifts/unknown", {}, user_session

    assert_equal 302, last_response.status
    assert_equal ["You have already submitted your lifts."], session[:message]
  end

  def test_view_known_lift_insertion_with_exisiting_lifts
    get "/lifts/known", {}, user_session

    assert_equal 302, last_response.status
    assert_equal ["You have already submitted your lifts."], session[:message]
  end

  def test_enter_unknown_lifts
    post "/lifts/unknown", projected_max_lifts

    assert_equal 302, last_response.status
    assert_in_delta bench_press[:projected_max], 282.68
    assert_in_delta bench_press[:training_max], 254.412
    assert_equal ["Lifts calculated successfully."], session[:message]
  end

  def test_enter_known_lifts
    post "/lifts/known", training_max_lifts

    assert_equal 302, last_response.status
    assert_in_delta bench_press[:training_max], 245.6788
    assert_equal ["Training maxes entered successfully."], session[:message]
  end

  def test_enter_unknown_lifts_with_existing_lifts
    post "/lifts/unknown", projected_max_lifts, user_session

    assert_equal 302, last_response.status
    assert_equal ["You have already submitted your lifts."], session[:message]
  end

  def test_enter_known_lifts_with_existing_lifts
    post "/lifts/known", training_max_lifts, user_session

    assert_equal 302, last_response.status
    assert_equal ["You have already submitted your lifts."], session[:message]
  end

  def test_enter_unknown_lifts_missing_input
    post "/lifts/unknown", projected_max_missing_lifts

    rep_range_message = "Please use a rep range between 1 and 20 for Squat."

    assert_equal 422, last_response.status
    assert_includes last_response.body, "Please enter a valid weight for Squat."
    assert_includes last_response.body, rep_range_message
    assert_nil session[:lifts]
  end

  def test_enter_known_lifts_missing_input
    post "/lifts/known", training_max_missing_lifts

    assert_equal 422, last_response.status
    assert_includes last_response.body, "Please enter a valid weight for Squat."
    assert_nil session[:lifts]
  end

  def test_view_increase_lift_insertion
    get "/lifts/increase", {}, user_session

    assert_equal 200, last_response.status
    assert_includes last_response.body, %(<form action="/lifts/increase")

    lifts_list.each do |lift|
      %w(weight reps).each do |param|
        assert_includes last_response.body, %(name="#{lift}_#{param}")
      end
    end
  end

  def test_view_increase_lift_insertion_without_existing_lifts
    get "/lifts/increase"

    assert_equal 302, last_response.status
    assert_equal ["Please enter your initial lifts."], session[:message]
  end

  def test_enter_lift_increases
    post "/lifts/increase", increase_max_lifts, user_session

    assert_in_delta bench_press[:projected_max], 282.68
    assert_in_delta bench_press[:training_max], 260.6788
    assert_equal ["Lifts calculated successfully."], session[:message]
  end

  def test_enter_lift_increases_without_existing_lifts
    post "/lifts/increase", increase_max_lifts

    assert_equal 302, last_response.status
    assert_equal ["Please enter your initial lifts."], session[:message]
  end

  def test_enter_lift_increases_missing_input
    post "/lifts/increase", increase_max_missing_lifts, user_session

    rep_range_message = "Please use a rep range between 1 and 20 for Squat."

    assert_equal 422, last_response.status
    assert_includes last_response.body, "Please enter a valid weight for Squat."
    assert_includes last_response.body, rep_range_message
  end

  def test_reset_lifts
    post "/lifts/reset", {}, user_session

    assert_equal 302, last_response.status
    assert_equal ["Your lifts have been reset."], session[:message]
  end

  def test_reset_lifts_without_existing_lifts
    post "/lifts/reset"

    assert_equal 302, last_response.status
    assert_equal ["Please enter your initial lifts."], session[:message]
  end

  def test_view_wave_selection
    get "/", {}, user_session

    assert_equal 200, last_response.status
    assert_includes last_response.body, %(<form action="/lifts/view")
    assert_includes last_response.body, %(<input type="radio" name="wave")
  end

  def test_view_wave_lifts
    get "/lifts/view", { wave: "10" }, user_session

    assert_equal 200, last_response.status
    assert_includes last_response.body, "135.0x5"
    assert_includes last_response.body, "155.0x5"
    assert_includes last_response.body, "165.0x3x10"
  end

  def test_view_wave_lifts_without_existing_lifts
    get "/lifts/view", { wave: "10" }

    assert_equal 302, last_response.status
    assert_equal ["Please enter your initial lifts."], session[:message]
  end

  def test_view_wave_lifts_invalid_wave
    get "/lifts/view", { wave: "9" }, user_session

    assert_equal 302, last_response.status
    assert_equal ["Please select a valid wave."], session[:message]
  end
end
