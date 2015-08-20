class Order < ActiveRecord::Base
  belongs_to :user
  after_update :total_price

  has_many :shipping_updates, dependent: :destroy
  has_many :refunds, dependent: :destroy
  has_many :order_items, dependent: :destroy
  has_many :users, through: :order_items
  
  accepts_nested_attributes_for :order_items, reject_if: :all_blank, allow_destroy: true
  accepts_nested_attributes_for :shipping_updates, reject_if: :all_blank, allow_destroy: true

  def self.shipping_price(order)
    @oi_shipping_price = order.order_items.map(&:shipping_price)
    @oi_max = @oi_shipping_price.max

    @total_shipp = []
    order.order_items.each do |oi|
      @total_shipp << oi.shipping_price * oi.quantity
    end
    shipping_price = (@oi_max + ((@total_shipp.sum - @oi_max ) * 0.65 ) ).round(2)
  end
  def self.total_price(order)
    @prod_shipp = order.order_items.map(&:total_price).sum + self.shipping_price(order)
    total_price = ((@prod_shipp.to_f.round(2)) + ((@prod_shipp.to_f.round(2)) * User.find(order.merchant_id).tax_rate / 100  ))
  end

  def self.send_to_keen(order, ip_address, location)
    Keen.publish("Orders", {
      marketplace_name: "MarketplaceBase",
      platform_for: 'apparel',
      ip_address: ip_address,
      customer_zipcode: location["zipcode"],
      customer_city: location["city"] ,
      customer_state: location["region_name"],
      customer_country: location["country_name"],
      order_year: Time.now.strftime("%Y").to_i,
      order_month: Time.now.strftime("%B").to_i,
      order_day: Time.now.strftime("%d").to_i,
      order_hour: Time.now.strftime("%H").to_i,
      order_minute: Time.now.strftime("%M").to_i,
      merchant_username: User.find(order.merchant_id).username,
      customer_name: order.user.legal_name,
      total_price: order.total_price.to_f,
      shipping_price: order.shipping_price.to_f,
      customer_sign_in_count: order.user.sign_in_count,
      order_uuid: order.uuid,
      submit_timestamp: order.updated_at
    })
    order.order_items.each do |oi|
    Keen.publish("Order Items", {
      marketplace_name: "MarketplaceBase",
      platform_for: 'apparel',
      ip_address: ip_address,
      customer_zipcode: location["zipcode"],
      customer_city: location["city"],
      customer_state: location["region_name"],
      customer_country: location["country_name"],
      order_year: Time.now.strftime("%Y").to_i,
      order_month: Time.now.strftime("%B").to_i,
      order_day: Time.now.strftime("%d").to_i,
      order_hour: Time.now.strftime("%H").to_i,
      order_minute: Time.now.strftime("%M").to_i,
      product_tags: oi.product_tags,
      price: oi.price.to_f,
      quantity: oi.quantity,
      total_price: oi.total_price.to_f,
      product_uuid: oi.product_uuid,
      order_uuid: oi.order.uuid,
      shipping_price: oi.shipping_price.to_f,
      merchant_username: User.find(order.merchant_id).username,
      customer_name: order.user.legal_name,
      order_item_id: oi.id,
      order_total_price: oi.total_price,
      })
    end
    order.order_items.each do |oi|
      if !Product.find_by(uuid: oi.product_uuid).tags.empty?
        Product.find_by(uuid: oi.product_uuid).tags.each do |tag|
        Keen.publish("Tags On Ordered Items", {
          marketplace_name: "MarketplaceBase",
          tag: tag.name, 
          order_uuid: oi.order.uuid, 
          order_item_id: oi.id,
          order_item_product_uuid: oi.product_uuid,
          order_total_price: oi.order.total_price.to_f,
          order_item_total_price: oi.total_price.to_f, 
        })
        end
      else
        @tags = Keen.publish("Tags On Ordered Items", {
          marketplace_name: "MarketplaceBase",
          tag: "None", 
          order_uuid: oi.order.uuid, 
          order_item_id: oi.id,
          order_item_product_uuid: oi.product_uuid,
          order_total_price: oi.order.total_price.to_f,
          order_item_total_price: oi.total_price.to_f, 
        })
      end
    end
  end
end
