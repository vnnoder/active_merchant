require 'test_helper'

class PayDollarTest < Test::Unit::TestCase
  def setup
    @gateway = PayDollarGateway.new(
        {
          :merchant => 'merchantId',
          :login => 'loginId',
          :password => 'password'
        }
      )

    @credit_card = credit_card
    @amount = 10

    @options = {
      :order_id => 'REF1',
      :currency => "702",
      :lang => "E"
    }
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert response.test?
    assert_equal 'Transaction completed', response.message
  end

  def test_successful_purchase_with_address
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
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
    assert response.test?
    assert_equal 'Transaction completed', response.message
  end

  def test_successful_authorize
    @gateway.expects(:ssl_post).returns(successful_authorization_response)

    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_success response
    assert_equal response.message, "Transaction completed"

    # Replace with authorization number from the successful response
    assert response.authorization
    assert response.test?
  end

  def test_failed_capture
    @gateway.expects(:ssl_post).returns(failed_capture_response)
    assert response = @gateway.capture(@amount, '')
    assert_failure response
    assert_equal 'Parameter Payment Reference Number Incorrect.', response.message
  end

  def test_invalid_merchant
    @gateway.expects(:ssl_post).returns(invalid_merchant_response)
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 'Parameter Merchant Id Incorrect', response.message
  end

  def test_invalid_login
    @gateway.expects(:ssl_post).returns(invalid_login_response)
    assert response = @gateway.capture(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 'Authentication Failed', response.message
  end

  def successful_purchase_response
    "successcode=0&Ref=REF1&PayRef=1296297&Amt=10.0&Cur=702&prc=0&src=0&Ord=12345678&Holder=Test Holder&AuthId=296297&TxTime=2013-11-21 12:01:36.0&errMsg=Transaction completed"
  end

  def successful_authorization_response
    "successcode=0&Ref=REF1&PayRef=1296294&Amt=10.0&Cur=702&prc=0&src=0&Ord=12345678&Holder=Test Holder&AuthId=296294&TxTime=2013-11-21 12:01:30.0&errMsg=Transaction completed"
  end

  def failed_capture_response
    "resultCode=-1&orderStatus=&ref=&payRef=&amt=&cur=&errMsg=Parameter Payment Reference Number Incorrect."
  end

  def invalid_merchant_response
    "successcode=-1&Ref=&PayRef=&Amt=&Cur=&prc=&src=&Ord=&Holder=&AuthId=&TxTime=&errMsg=Parameter Merchant Id Incorrect"
  end

  def invalid_login_response
    "resultCode=-1&orderStatus=&ref=&payRef=&amt=&cur=&errMsg=Authentication Failed"
  end
private

  def credit_card
    Struct.new("CreditCard", :brand, :month, :year, :number, :name, :verification_value)
    return Struct::CreditCard.new("VISA", 7, 2015, "4918914107195005", "Test Holder", "123")
  end

end
