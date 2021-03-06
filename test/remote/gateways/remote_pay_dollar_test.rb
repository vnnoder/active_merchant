require 'test_helper'

class RemotePayDollarTest < Test::Unit::TestCase
  def setup
    @gateway = PayDollarGateway.new(fixtures(:pay_dollar))

    @credit_card = credit_card("VISA", "07", "2015", "4918914107195005", "Test Holder", "123")
    @amount = 10

    @options = {
      :order_id => "#{(Time.now.to_f * 1000).round}",
      :currency => "840",
      :lang => "E"
    }
  end

  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal response.message, "Transaction completed"
    assert response.test?
  end

  def test_successful_purchase_with_address
    address = {
      :name => "Test Holder",
      :address1 => "Test Address 1",
      :address2 => "Test Address 2",
      :city => "Test City",
      :state => "",
      :zip => "",
      :country => "Test Country",
      :email => "test@example.com",
      :ip => "192.168.180.100"
    }
    @options.update({:address => address})
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal response.message, "Transaction completed"
    assert response.test?
  end

  def test_successful_authorize
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
    assert_equal response.message, "Transaction completed"

    # Replace with authorization number from the successful response
    assert response.authorization
    assert response.test?
  end

  def test_authorize_and_capture
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
    assert_equal response.message, "Transaction completed"
    assert response.authorization
    assert response.test?

    assert response = @gateway.capture(@amount, response.authorization, @options)
    assert_success response
    assert_equal response.message, "Capture Successfully."
    assert response.test?
  end

  def test_authorize_and_reverse
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
    assert_equal response.message, "Transaction completed"
    assert response.authorization
    assert response.test?

    assert response = @gateway.reverse_authorization(response.authorization, @options)
    assert_success response
    puts response.message
    assert response.test?
  end

  def test_purchase_and_void
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal response.message, "Transaction completed"
    assert response.test?

    assert response = @gateway.void(response.authorization, @options)
    assert_success response
    assert_equal response.message, "Void Successfully."
  end

  def test_failed_capture
    assert response = @gateway.capture(@amount, '')
    assert_failure response
    assert_equal 'Parameter Payment Reference Number Incorrect.', response.message
  end

  def test_invalid_merchant
    gateway = PayDollarGateway.new({
        :merchant => ''
      })
    assert response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 'Parameter Merchant Id Incorrect', response.message
  end

  def test_invalid_login
    gateway = PayDollarGateway.new(fixtures(:pay_dollar).update(
        {
          :login => '',
          :password => ''
        }
      ))
    assert response = gateway.capture(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 'Authentication Failed', response.message
  end

  def test_successful_add_membership
    gateway = PayDollarGateway.new(fixtures(:pay_dollar))
    @options[:customer] = "customer#{(Time.now.to_f * 1000).round}"
    @options[:name] = "John Doe"

    assert response = @gateway.add_membership(@options)
    assert_success response
    assert_equal 'OK', response.message
    assert response.test?

  end

  def test_add_membership_and_store_card
    gateway = PayDollarGateway.new(fixtures(:pay_dollar))
    @options[:customer] = "customer#{(Time.now.to_f * 1000).round}"
    @options[:name] = "John Doe"

    assert response = @gateway.add_membership(@options)
    assert_success response
    assert_equal 'OK', response.message
    assert response.test?


    assert response = @gateway.store(@credit_card, @options)
    assert_success response
    assert_equal 'OK', response.message
    assert response.test?
    assert response.token
  end

  def test_add_membership_store_and_retrieve_card
    gateway = PayDollarGateway.new(fixtures(:pay_dollar))
    @options[:customer] = "customer#{(Time.now.to_f * 1000).round}"
    @options[:name] = "John Doe"

    assert response = @gateway.add_membership(@options)
    assert_success response
    assert_equal 'OK', response.message
    assert response.test?


    assert response = @gateway.store(@credit_card, @options)
    assert_success response
    assert_equal 'OK', response.message
    assert response.test?
    assert response.token

    assert response = @gateway.retrieve_card(response.token, @options)
    assert_success response
    assert_equal 'OK', response.message
    assert response.test?
  end

  def test_add_membership_store_and_delete_card
    gateway = PayDollarGateway.new(fixtures(:pay_dollar))
    @options[:customer] = "customer#{(Time.now.to_f * 1000).round}"
    @options[:name] = "John Doe"

    assert response = @gateway.add_membership(@options)
    assert_success response
    assert_equal 'OK', response.message
    assert response.test?


    assert response = @gateway.store(@credit_card, @options)
    assert_success response
    assert_equal 'OK', response.message
    assert response.test?
    assert response.token

    assert response = @gateway.delete_card(response.token, @options)
    assert_success response
    assert_equal 'OK', response.message
    assert response.test?
  end


  def test_add_membership_store_card_and_purchase
    gateway = PayDollarGateway.new(fixtures(:pay_dollar))
    @options[:customer] = "customer#{(Time.now.to_f * 1000).round}"
    @options[:name] = "John Doe"

    assert response = @gateway.add_membership(@options)
    assert_success response
    assert_equal 'OK', response.message
    assert response.test?


    assert response = @gateway.store(@credit_card, @options)
    assert_success response
    assert_equal 'OK', response.message
    assert response.test?
    assert response.token
    puts "========================"

    assert response = @gateway.purchase(@amount,response.token, @options)
    assert_success response
    assert_equal response.message, "Transaction completed"
    assert response.test?
  end

  def test_add_membership_store_card_authorize_and_capture
    gateway = PayDollarGateway.new(fixtures(:pay_dollar))
    @options[:customer] = "customer#{(Time.now.to_f * 1000).round}"
    @options[:name] = "John Doe"

    assert response = @gateway.add_membership(@options)
    assert_success response
    assert_equal 'OK', response.message
    assert response.test?


    assert response = @gateway.store(@credit_card, @options)
    assert_success response
    assert_equal 'OK', response.message
    assert response.test?
    assert response.token
    puts "========================"

    assert response = @gateway.authorize(@amount,response.token, @options)
    assert_success response
    assert_equal response.message, "Transaction completed"
    assert response.authorization
    assert response.test?

    assert response = @gateway.capture(@amount, response.authorization, @options)
    assert_success response
    assert_equal response.message, "Capture Successfully."
    assert response.test?
  end

  def test_recurring
    gateway = PayDollarGateway.new(fixtures(:pay_dollar))
    options = {
      :start_day => Date.today.day,
      :start_month => Date.today.month,
      :start_year => Date.today.year,
      :email => "user@example.com",
      :number_of_type => 1,
      :schedule_type => "Day"
    }.merge!(@options)
    assert response = gateway.recurring(99, @credit_card, options)
    assert_success response
    assert_equal "Add Successfully.", response.message
  end

  def test_status_recurring
    gateway = PayDollarGateway.new(fixtures(:pay_dollar))
    assert response = gateway.status_recurring(38303, @options)
    assert_success response
    master = response.params
    assert master && master["mSchPayId"] && master["schType"] && master["startDate"] && master["endDate"] && master["merRef"] && master["amount"] && master["payType"] && master["payMethod"] && master["account"] && master["holder"] && master["expiryDate"] && master["status"] && master["suspendDate"] && master["lastTerminateDate"] && master["reActivateDate"] && master["detailSchPay"]

    detail = master["detailSchPay"]
    assert detail.is_a? Array
    detail.each do |d|
      assert d[:dSchPayId] && d[:schType] && d[:orderDate] && d[:tranDate] && d[:currency] && d[:amount] && d[:status] && d[:payRef]
    end
  end

  def test_cancel_recurring
    gateway = PayDollarGateway.new(fixtures(:pay_dollar))
    options = {
      :start_day => Date.today.day,
      :start_month => Date.today.month,
      :start_year => Date.today.year,
      :email => "user@example.com",
      :number_of_type => 1,
      :schedule_type => "Day"
    }.merge!(@options)
    assert response = gateway.recurring(99, @credit_card, options)
    assert_success response
    schedule_id = response.params["mSchPayId"]

    assert response = gateway.cancel_recurring(schedule_id, @options)
    assert_success response
    assert_equal "Suspend successfully.", response.message
  end

  def test_reactivate_recurring
    gateway = PayDollarGateway.new(fixtures(:pay_dollar))
    options = {
      :start_day => Date.today.day,
      :start_month => Date.today.month,
      :start_year => Date.today.year,
      :email => "user@example.com",
      :number_of_type => 1,
      :schedule_type => "Day"
    }.merge!(@options)
    assert response = gateway.recurring(99, @credit_card, options)
    assert_success response
    schedule_id = response.params["mSchPayId"]

    assert response = gateway.cancel_recurring(schedule_id, @options)
    assert_success response

    assert response = gateway.reactivate_recurring(schedule_id, @options)
    assert_success response
    assert_equal "Reactivate successfully.", response.message
  end

  def test_delete_recurring
    gateway = PayDollarGateway.new(fixtures(:pay_dollar))
    options = {
      :start_day => Date.today.day,
      :start_month => Date.today.month,
      :start_year => Date.today.year,
      :email => "user@example.com",
      :number_of_type => 1,
      :schedule_type => "Day"
    }.merge!(@options)

    assert response = gateway.recurring(99, @credit_card, options)
    assert_success response
    schedule_id = response.params["mSchPayId"]

    assert response = gateway.delete_recurring(schedule_id, @options)
    assert_success response
    assert_equal "Delete successfully.", response.message
  end

private

  def credit_card(brand, month, year, number, name, verification_value)
    Struct.new("CreditCard", :brand, :month, :year, :number, :name, :verification_value)
    return Struct::CreditCard.new(brand, month, year, number, name, verification_value)
  end

end
