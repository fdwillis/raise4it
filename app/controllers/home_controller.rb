class HomeController < ApplicationController
  caches_page :home
  def home
    unless !current_user
        redirect_to fundraising_goals_path
    end
    #Track For Admin
    # if !current_user  
    #   Keen.publish("Homepage Visits", { 
    #     visitor_city: request.location.data["city"],
    #     visitor_state: request.location.data["region_name"],
    #     visitor_country: request.location.data["country_code"],
    #     date: DateTime.now.to_date.strftime("%A, %B #{DateTime.now.to_date.day.ordinalize}"),
    #     year: Time.now.strftime("%Y").to_i,
    #     month: DateTime.now.to_date.strftime("%B"),
    #     day: Time.now.strftime("%d").to_i,
    #     hour: Time.now.strftime("%H").to_i,
    #     minute: Time.now.strftime("%M"),
    #     day_of_week: DateTime.now.to_date.strftime("%A"),
    #     timestamp: Time.now,
    #     marketplace_name: ENV["MARKETPLACE_NAME"]
    #   })
    # end
  end
  def terms
      
  end

  def donation_history
    @donations = Donation.all.where(organization: current_user.username)
  end
end
