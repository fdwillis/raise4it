class ReportsController < ApplicationController
  before_filter :authenticate_user!
  include ActionView::Helpers::NumberHelper
  def index
    if (current_user.account_approved? && !current_user.roles.nil?) || current_user.admin? 
      if current_user.admin?
        @sign_ups_month = area_chart(current_user.sign_ups, "Sign Ups This Month", "Sign Ups", :start_month, DateTime.now.strftime("%m"), :start_day)
        @sign_ups_year = area_chart(current_user.sign_ups, "Sign Ups This Year", "Sign Ups", :start_year, DateTime.now.strftime("%Y"), :start_month) 
      else
        User.decrypt_and_verify(current_user.merchant_secret_key)
        Stripe.api_key = Rails.configuration.stripe[:secret_key]
      end
        #Donation column Chart
          #Data
          @colum = area_chart(current_user.rake_donations, "Donations This Month", "Donations", :start_month, DateTime.now.strftime("%m"), :start_day)
          @column = area_chart(current_user.rake_donations, "Donations This Year", "Donations", :start_year, DateTime.now.strftime("%Y"), :start_month) 

        # #Donation pie Chart
        #   pie_type_data = [
        #     {
        #       'data' => donation_pie(current_user.id, "donation_type")
        #     }
        #   ]

        #   pie_day_data = [
        #     {
        #       'data' => donation_pie(current_user.id, "day_of_week")
        #       }
        #   ]
        #   pie_city_data = [
        #     {
        #       'data' => donation_pie(current_user.id, "customer_current_city")
        #       }
        #   ]
        #   @pie_type = pie_chart(pie_type_data, 'donation_type', "Donations By Type")
        #   @pie_week = pie_chart(pie_day_data, 'day_of_week', "Donations By Day")
        #   @pie_city = pie_chart(pie_city_data, 'customer_current_city', "Donations By City")

        # Donation area chart  
          @area = area_chart(current_user.rake_donations, "Donation Revenue This Month", "Dollars", :start_month, DateTime.now.strftime("%m"), :start_day)        
    else
      redirect_to plans_path
      flash[:error] = "You dont have permission to access reports. You must signup"
      return
    end
  end

private

  def column_chart(data, title, timeframe)
    LazyHighCharts::HighChart.new('graph') do |f|
      f.colors([ '#434348', '#7CB5EC','#90ED7D'])
      f.title(:text => title)
      f.xAxis(:categories => timeframe)
      data.each do | data|
        f.series(
          name: data['name'], 
          data: data['data'].map{|d| d['value'] },
          yAxis: 0,
        )
      end
      f.yAxis(title: {:text => "Dollars"} )
      f.legend(layout: "horizontal")
      f.chart(type: "column")
      f.tooltip(shared: true)
    end
  end

  def pie_chart(data, group, title)
    LazyHighCharts::HighChart.new('pie') do |f|
      f.chart(
        {
          :defaultSeriesType=>"pie", 
          
        }
      )
      f.series(:type=> 'pie',
                name: "Percent",
               :data=> data[0]['data'].map{|d| [d[group], (d['result'] / data[0]['data'].map{|d| d['result']}.sum.to_f * 100).to_i]})
      f.title(text: title)
      f.plotOptions(
        pie: {
          dataLabels: {
            enabled: false,
          }, 
          showInLegend: true,
          allowPointSelect: true,
          cursor: 'pointer',
        }
      )
      f.legend(layout: "horizontal")
    end
  end

  def area_chart(data, title, axis_title, timeframe, date, interval)
    LazyHighCharts::HighChart.new('graph') do |f|
      f.colors(['#7CB5EC','#90ED7D'])
      f.chart(type: 'area')
      f.title(text: title)
      if timeframe == :start_year
        months = 1..12
        data_values = []
        months.each do |month|
          data_values << data.where(start_month: (sprintf '%02d', month)).map(&:value).sum
        end
        f.series(data: data_values, name: axis_title)
        f.xAxis(type: 'datetime', categories: Date::MONTHNAMES.slice(1..12))
      else
        values = data.where("user_id = ?", current_user.id).where("#{timeframe} = ? ", "#{date}")
        f.series(data: values.map{|d| d.value}, 
                 name: axis_title )
        f.xAxis(type: 'datetime', categories: values.map{|d| d[interval]}.uniq)
      end
      f.yAxis(title: {text: axis_title})
      f.tooltip(shared: true)
      f.legend(layout: "horizontal")
      f.plotOptions(
        series:{
          fillOpacity: 0.8
        }
      )
    end
  end
end