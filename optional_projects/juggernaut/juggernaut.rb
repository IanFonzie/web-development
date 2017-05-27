require "sinatra"
require "sinatra/reloader"
require "tilt/erubis"
require "pry"

configure do
  enable :sessions
  set :session_secret, "super duper secret"
end

def lifts_list
  %w(bench_press squat deadlift press)
end

def projected_max(weight, reps)
  (weight.to_i * reps.to_i * 0.033) + weight.to_i
end

def append_string(symbol, string)
  (symbol.to_s + "_" + string).to_sym
end

def increase_max(reps, wave, increment, lift)
  ((reps.to_i - wave.to_i) * increment) + session[:lifts][lift][:training_max]
end

def increment_selector(reps, wave, lift)
  projected_max = session[:lifts][lift][:projected_max]

  case lift
  when :bench_press, :press
    projected_max / increase_max(reps, wave, 2.5, lift) > 1.05 ? 2.5 : 1.25
  when :squat, :deadlift
    projected_max / increase_max(reps, wave, 5, lift) > 1.05 ? 5 : 2.5
  end
end

def lifts_exist?
  session.key?(:lifts)
end

def require_new_user
  return unless lifts_exist?
  session[:message] = ["You have already submitted your lifts."]
  redirect "/"
end

def require_existing_user
  return if lifts_exist?
  session[:message] = ["Please enter your initial lifts."]
  redirect "/"
end

def error_for_weight(weight, lift)
  return if (1..1300).cover? weight.to_f
  "Please enter a valid weight for #{lift_name(lift.to_s)}."
end

def error_for_reps(reps, lift)
  return if (1..20).cover? reps.to_i
  "Please use a rep range between 1 and 20 for #{lift_name(lift.to_s)}."
end

def capture_errors(errors, error_list)
  lift_errors = error_list.each_with_object([]) do |error, errors_array|
    errors_array << error if error
  end

  if lift_errors.empty?
    yield
  else
    errors << lift_errors
  end
end

def validate_input(errors, view)
  if errors.flatten.empty?
    yield
  else
    session.delete(:lifts)
    status 422
    session[:message] = errors.flatten
    erb view
  end
end

def select_multiple(index, list)
  index.zero? || (index == 3) || (index == list.size - 1) ? 2.5 : 5.0
end

def round_to_nearest_multiple(value, nearest_multiple)
  (value / nearest_multiple).round * nearest_multiple
end

def ten_wave
  percentages = [0.6, 0.55, 0.625, 0.675, 0.5, 0.6, 0.7, 0.75]
  reps = %w(x5x10 x5 x5 x3x10 x5 x3 x1 xAMAP)

  percentages.zip(reps)
end

def eight_wave
  percentages = [0.65, 0.6, 0.675, 0.725, 0.5, 0.6, 0.7, 0.75, 0.8]
  reps = %w(x5x8 x3 x3 x3x8 x5 x3 x2 x1 xAMAP)

  percentages.zip(reps)
end

def five_wave
  percentages = [0.7, 0.65, 0.725, 0.775, 0.5, 0.6, 0.7, 0.75, 0.8, 0.85]
  reps = %w(x6x5 x2 x2 x4x5 x5 x3 x2 x1 x1 xAMAP)

  percentages.zip(reps)
end

def three_wave
  percentages = [0.75, 0.7, 0.775, 0.825, 0.5, 0.6, 0.7, 0.75, 0.8, 0.85, 0.9]
  reps = %w(x7x3 x1 x1 x5x3 x5 x3 x2 x1 x1 x1 xAMAP)

  percentages.zip(reps)
end

def percentage_array(wave)
  case wave
  when "10" then ten_wave
  when "8" then eight_wave
  when "5" then five_wave
  when "3" then three_wave
  else
    session[:message] = ["Please select a valid wave."]
    redirect "/"
  end
end

helpers do
  def lift_name(lift)
    name = lift == "bench_press" ? lift.tr("_", " ") : lift
    name.capitalize
  end

  def format_lift_numbers(lift)
    format("%.3f", lift) if lift
  end

  def cell_name_selector(num, list)
    case num
    when 0
      "<td>Accumulation</td>"
    when 1
      "<td rowspan='3'>Intensification</td>"
    when 4
      "<td rowspan='#{list.size - 4}'>Realization</td>"
    end
  end

  def format_table_output(lifts, set_info, index)
    lift = lifts_list[index].to_sym
    weight = lifts[set_info][0] * session[:lifts][lift][:training_max]
    multiple = select_multiple(set_info, lifts)
    "#{round_to_nearest_multiple(weight, multiple)}#{lifts[set_info][1]}"
  end
end

get "/" do
  erb :index
end

get "/lifts/increase" do
  require_existing_user

  erb :increase
end

get "/lifts/unknown" do
  require_new_user

  erb :lifts_estimate
end

get "/lifts/known" do
  require_new_user

  erb :lifts_known
end

post "/lifts/unknown" do
  require_new_user

  session[:lifts] = lifts_list.each_with_object({}) do |lift, hash|
    hash[lift.to_sym] = {}
  end

  # { bench_press: {}, squat: {}, deadlift: {}, press: {} }

  errors = []

  session[:lifts].each do |lift, _|
    weight = params[append_string(lift, "weight")].strip
    reps = params[append_string(lift, "reps")].strip
    lift_name = session[:lifts][lift]

    error_list = [
      error_for_weight(weight, lift.to_s),
      error_for_reps(reps, lift.to_s)
    ]

    capture_errors(errors, error_list) do
      lift_name[:projected_max] = projected_max(weight, reps)
      lift_name[:training_max] = lift_name[:projected_max] * 0.9
    end
  end

  validate_input(errors, :lifts_estimate) do
    session[:message] = ["Lifts calculated successfully."]
    redirect "/"
  end
end

post "/lifts/known" do
  require_new_user

  session[:lifts] = lifts_list.each_with_object({}) do |lift, hash|
    hash[lift.to_sym] = {}
  end

  errors = []

  session[:lifts].each do |lift, _|
    training_max = params[append_string(lift, "training_max")].strip

    error_list = [error_for_weight(training_max, lift)]

    capture_errors(errors, error_list) do
      session[:lifts][lift][:training_max] = training_max.to_f
    end
  end

  validate_input(errors, :lifts_known) do
    session[:message] = ["Training maxes entered successfully."]
    redirect "/"
  end
end

post "/lifts/increase" do
  require_existing_user

  errors = []

  session[:lifts].each do |lift, _|
    weight = params[append_string(lift, "weight")].strip
    reps = params[append_string(lift, "reps")].strip
    lift_name = session[:lifts][lift]

    error_list = [
      error_for_weight(weight, lift.to_s),
      error_for_reps(reps, lift.to_s)
    ]

    capture_errors(errors, error_list) do
      lift_name[:projected_max] = projected_max(weight, reps)

      increment = increment_selector(reps, params[:wave], lift)
      lift_name[:training_max] = increase_max(
        reps,
        params[:wave],
        increment,
        lift
      )
    end
  end

  validate_input(errors, :increase) do
    session[:message] = ["Lifts calculated successfully."]
    redirect "/"
  end
end

post "/lifts/reset" do
  require_existing_user

  session.delete(:lifts)
  session[:message] = ["Your lifts have been reset."]

  redirect "/"
end

get "/lifts/view" do
  require_existing_user
  
  wave = params[:wave]

  @lifts = percentage_array(wave)
  erb :wave
end

not_found do
  session[:message] = ["The file you're looking for does not exist."]
  redirect "/"
end
