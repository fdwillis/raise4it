class HomeController < ApplicationController
  def home
    unless !current_user
        redirect_to fundraising_goals_path
    end
    if !current_user && Rails.env.production? 
      get = request.location.data
      Keen.publish("Homepage Visits", { 
        ip: get['ip'],
        city: get['city'],
        region_code: get['region_code'], 
        region_name: get['region_name'],
        metrocode: get['metrocode'],
        zipcode: get['zipcode'],
        latitude: get['latitude'], 
        longitude: get['longitude'],
        country_name: get['country_name'], 
        country_code: get['country_code'], 
        year: Time.now.strftime("%Y").to_i,
        month: DateTime.now.to_date.strftime("%B"),
        day: Time.now.strftime("%d").to_i,
        hour: Time.now.strftime("%H").to_i,
        minute: Time.now.strftime("%M").to_i,
        day_of_week: DateTime.now.to_date.strftime("%A"),
        am_or_pm: Time.now.strftime("%p")
        }
      )
    end
  end
  def terms
      
  end

  def donation_history
    @donations = Donation.all.where(organization: current_user.username)
  end
end
