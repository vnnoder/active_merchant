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

    @credit_card = credit_card("VISA", "07", "2015", "4918914107195005", "Test Holder", "123")
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
    assert_equal 'Transaction completed', response.message
  end

  def test_successful_authorize
    @gateway.expects(:ssl_post).returns(successful_authorization_response)

    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
    assert_equal response.message, "Transaction completed"

    # Replace with authorization number from the successful response
    assert response.authorization
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

  def test_successful_add_membership
    @gateway.expects(:ssl_post).returns(successful_add_membership_response)
    @options[:customer] = "customer#{(Time.now.to_f * 1000).round}"
    @options[:name] = "John Doe"

    assert response = @gateway.add_membership(@options)
    assert_success response
    assert_equal 'OK', response.message
  end

  def test_retrieve_card
    @gateway.expects(:ssl_post).returns(successful_query_memberpay_response)
    @options[:customer] = "customer#{(Time.now.to_f * 1000).round}"
    @options[:name] = "John Doe"

    assert response = @gateway.retrieve_card(@options)
    assert_success response
    assert_equal 'OK', response.message
    acc = response.params["account"]
    assert acc[:accountId] && acc[:accounttype] && acc[:account] && acc[:expyear] && acc[:expmonth] && acc[:holdername] && acc[:status]
  end

  def test_delete_card
    @gateway.expects(:ssl_post).returns(successful_delete_card_response)
    @options[:customer] = "customer#{(Time.now.to_f * 1000).round}"

    assert response = @gateway.delete_card(@options)
    assert_success response
    assert_equal 'OK', response.message
  end

  def test_recurring
    @gateway.expects(:ssl_post).returns(successful_recurring_response)
    options = {
      :start_day => Date.today.day,
      :start_month => Date.today.month,
      :start_year => Date.today.year,
      :email => "user@example.com",
      :number_of_type => 1,
      :schedule_type => "Day"
    }.merge!(@options)

    assert response = @gateway.recurring(99, @credit_card, options)
    assert_success response
    assert_equal "Add Successfully.", response.message
  end

  def test_invalid_recurring
    @gateway.expects(:ssl_post).returns(invalid_recurring_response)
    options = {
      :start_day => Date.today.day,
      :start_month => Date.today.month,
      :start_year => Date.today.year,
      :email => "user@example.com",
      :number_of_type => 1,
      :schedule_type => "Day"
    }.merge!(@options)

    assert response = @gateway.recurring(99, @credit_card, options)
    assert_failure response
  end

  def test_status_recurring
    @gateway.expects(:ssl_post).returns(successful_status_recurring_response)

    assert response = @gateway.status_recurring(38303, @options)
    master = response.params
    assert master && master["mSchPayId"] && master["schType"] && master["startDate"] && master["endDate"] && master["merRef"] && master["amount"] && master["payType"] && master["payMethod"] && master["account"] && master["holder"] && master["expiryDate"] && master["status"] && master["suspendDate"] && master["lastTerminateDate"] && master["reActivateDate"] && master["detailSchPay"]

    detail = master["detailSchPay"]
    assert detail.is_a? Array
    detail.each do |d|
      assert d[:dSchPayId] && d[:schType] && d[:orderDate] && d[:tranDate] && d[:currency] && d[:amount] && d[:status] && d[:payRef]
    end
  end

  def test_status_recurring_single_detail
    @gateway.expects(:ssl_post).returns(successful_status_recurring_single_response)

    assert response = @gateway.status_recurring(38303, @options)
    detail = response.params["detailSchPay"]
    assert detail.is_a? Array
  end

  def test_invalid_status_recurring
    @gateway.expects(:ssl_post).returns(invalid_status_recurring_response)

    assert response = @gateway.status_recurring(3826300, @options)
  end

  def test_cancel_recurring_success
    @gateway.expects(:ssl_post).returns(successful_cancel_recurring_response)
    assert response = @gateway.cancel_recurring(38465, @options)
    assert_equal response.message, "Suspend successfully."
    assert_success response
  end

  def test_invalid_cancel_recurring
    @gateway.expects(:ssl_post).returns(invalid_cancel_recurring_response)
    assert response = @gateway.cancel_recurring(38465, @options)
    assert_failure response
  end

  def test_reactivate_recurring_success
    @gateway.expects(:ssl_post).returns(successful_reactivate_recurring_response)
    assert response = @gateway.reactivate_recurring(38465, @options)
    assert_equal response.message, "Reactivate successfully."
    assert_success response
  end

  def test_invalid_reactivate_recurring
    @gateway.expects(:ssl_post).returns(invalid_reactivate_recurring_response)
    assert response = @gateway.reactivate_recurring(38465, @options)
    assert_failure response
  end

  protected

    def successful_delete_card_response
      <<-RESPONSE
  <membershipresponse>
    <action>Delete</action>
    <responsestatus>
        <responsecode>0</responsecode>
        <responsemessage>OK</responsemessage>
    </responsestatus>
    <response/>
  </membershipresponse>
      RESPONSE
    end

    def successful_query_memberpay_response
      <<-RESPONSE
  <memberpayresponse>
    <action>Query</action>
    <responsestatus>
      <responsecode>0</responsecode>
      <responsemessage>OK</responsemessage>
    </responsestatus>
    <response>
      <account>
        <accountId>1</accountId>
        <accounttype>VISA</accounttype>
        <account>491891******5005</account>
        <expyear>2015</expyear>
        <expmonth>7</expmonth>
        <holdername>Test Holder</holdername>
        <status>A</status>
      </account>
    </response>
  </memberpayresponse>
      RESPONSE
    end

    def successful_add_membership_response
      <<-STORE_RESPONSE
  <?xml version="1.0" encoding="ISO-8859-1"?>
    <membershipresponse>
      <action>Add</action>
      <responsestatus>
        <responsecode>0</responsecode>
        <responsemessage>OK</responsemessage>
      </responsestatus>
    <response/>
  </membershipresponse>
      STORE_RESPONSE
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

    def successful_recurring_response
      "resultCode=0&mSchPayId=38262&merchantId=12103014&orderRef=SCH1&status=Active&errMsg=Add Successfully."
    end

    def invalid_recurring_response
      "resultCode=-1&mSchPayId=&merchantId=&orderRef=&status=&errMsg=Parameter cardNo don't match card Type"
    end

    def successful_status_recurring_response
      <<-RESPONSE
  <?xml version="1.0" encoding="ISO-8859-1"?>
  <records>
  <masterSchPay>
  <mSchPayId>38303</mSchPayId>
  <schType>1 Day</schType>
  <startDate>2014-07-24 00:00:00.0</startDate>
  <endDate>null</endDate>
  <merRef>1406193882834</merRef>
  <amount>99</amount>
  <payType>N</payType>
  <payMethod>VISA</payMethod>
  <account>491891******5005</account>
  <holder>Test Holder</holder>
  <expiryDate>7/2015</expiryDate>
  <status>Active</status>
  <suspendDate>null</suspendDate>
  <lastTerminateDate>null</lastTerminateDate>
  <reActivateDate>null</reActivateDate>
  <detailSchPay>
  <dSchPayId>606314</dSchPayId>
  <schType>1 Day</schType>
  <orderDate>2014-07-24 00:00:00.0</orderDate>
  <tranDate>2014-07-25 00:00:00.0</tranDate>
  <currency>US</currency>
  <amount>99</amount>
  <status>Accepted</status>
  <payRef>1597533</payRef>
  </detailSchPay>
  <detailSchPay>
  <dSchPayId>606559</dSchPayId>
  <schType>1 Day</schType>
  <orderDate>2014-07-25 00:00:00.0</orderDate>
  <tranDate>2014-07-26 00:00:00.0</tranDate>
  <currency>US</currency>
  <amount>99</amount>
  <status>Accepted</status>
  <payRef>1598758</payRef>
  </detailSchPay>
  </masterSchPay>
  </records>
      RESPONSE
    end

    def successful_status_recurring_single_response
      <<-RESPONSE
  <?xml version="1.0" encoding="ISO-8859-1"?>
  <records>
  <masterSchPay>
  <mSchPayId>38303</mSchPayId>
  <schType>1 Day</schType>
  <startDate>2014-07-24 00:00:00.0</startDate>
  <endDate>null</endDate>
  <merRef>1406193882834</merRef>
  <amount>99</amount>
  <payType>N</payType>
  <payMethod>VISA</payMethod>
  <account>491891******5005</account>
  <holder>Test Holder</holder>
  <expiryDate>7/2015</expiryDate>
  <status>Active</status>
  <suspendDate>null</suspendDate>
  <lastTerminateDate>null</lastTerminateDate>
  <reActivateDate>null</reActivateDate>
  <detailSchPay>
  <dSchPayId>606314</dSchPayId>
  <schType>1 Day</schType>
  <orderDate>2014-07-24 00:00:00.0</orderDate>
  <tranDate>2014-07-25 00:00:00.0</tranDate>
  <currency>US</currency>
  <amount>99</amount>
  <status>Accepted</status>
  <payRef>1597533</payRef>
  </detailSchPay>
  </masterSchPay>
  </records>
      RESPONSE
    end

    def invalid_status_recurring_response
      <<-RESPONSE
  <?xml version="1.0" encoding="ISO-8859-1"?>
  <records>
  <masterSchPay>
  </masterSchPay>
  </records>
      RESPONSE
    end

    def successful_cancel_recurring_response
      "resultCode=0&mSchPayId=38465&merchantId=12103014&orderRef=1407144798186&status=Suspend&errMsg=Suspend successfully."
    end

    def successful_reactivate_recurring_response
      "resultCode=0&mSchPayId=38465&merchantId=12103014&orderRef=1407144798186&status=Active&errMsg=Reactivate successfully."
    end

    def invalid_cancel_recurring_response
      "resultCode=-1&mSchPayId=&merchantId=&orderRef=&status=&errMsg=The transaction already Suspended."
    end

    def invalid_reactivate_recurring_response
      "resultCode=-1&mSchPayId=&merchantId=&orderRef=&status=&errMsg=The transaction already Activated."
    end

  private
    def credit_card(brand, month, year, number, name, verification_value)
      Struct.new("CreditCard", :brand, :month, :year, :number, :name, :verification_value)
      return Struct::CreditCard.new(brand, month, year, number, name, verification_value)
    end

end
