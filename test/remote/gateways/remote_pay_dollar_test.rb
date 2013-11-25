require 'test_helper'

class RemotePayDollarTest < Test::Unit::TestCase
  def setup
    @gateway = PayDollarGateway.new(fixtures(:pay_dollar))

    @credit_card = credit_card
    @amount = 10

    @options = {
      :order_id => "test#{(Time.now.to_f * 1000).round}",
      :currency => "702",
      :lang => "E"
    }
  end

  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of Response, response
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
    assert_instance_of Response, response
    assert_success response
    assert_equal response.message, "Transaction completed"
    assert response.test?
  end

  def test_successful_authorize
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_success response
    assert_equal response.message, "Transaction completed"

    # Replace with authorization number from the successful response
    assert response.authorization
    assert response.test?
  end

  def test_authorize_and_capture
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_success response
    assert_equal response.message, "Transaction completed"
    assert response.authorization
    assert response.test?

    assert response = @gateway.capture(@amount, response.authorization, @options)
    assert_instance_of Response, response
    assert_success response
    assert_equal response.message, "Capture Successfully."
    assert response.test?
  end

  def test_purchase_and_void
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_success response
    assert_equal response.message, "Transaction completed"
    assert response.test?

    assert response = @gateway.void(response.authorization, @options)
    assert_instance_of Response, response
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

  def test_successful_card_store
    gateway = PayDollarGateway.new(fixtures(:pay_dollar))
    @options[:customer] = "customer#{(Time.now.to_f * 1000).round}"
    @options[:name] = "John Doe"

    assert response = @gateway.store(@credit_card, @options)
    assert_success response
    assert_equal 'OK', response.message
    assert response.test?
    assert response.token
  end

private

  def credit_card
    Struct.new("CreditCard", :brand, :month, :year, :number, :name, :verification_value)
    return Struct::CreditCard.new("VISA", "07", "2015", "4918914107195005", "Test Holder", "123")
  end

end
