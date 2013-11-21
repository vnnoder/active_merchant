module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class PayDollarGateway < Gateway
      class_attribute :test_merchant_url, :live_merchant_url

      PURCHASE_HOLD = 'H'
      PURCHASE_NORMAL = 'N'

      self.test_url = 'https://test.paydollar.com/b2cDemo/eng/directPay/payComp.jsp'
      self.live_url = 'https://www.paydollar.com/b2c2/eng/directPay/payComp.jsp'
      self.test_merchant_url = 'https://test.paydollar.com/b2cDemo/eng/merchant/api/orderApi.jsp'
      self.live_merchant_url = 'https://www.paydollar.com/b2c2/eng/merchant/api/orderApi.jsp'

      # The countries the gateway supports merchants from as 2 digit ISO country codes
      self.supported_countries = %w[ HK MY SG US CN ]

      # The card types supported by the payment gateway
      self.supported_cardtypes = [ :visa, :master, :american_express, :diners_club, :jcb ]

      # The homepage URL of the gateway
      self.homepage_url = 'http://paydollar.com/'

      # The name of the gateway
      self.display_name = 'PayDollar'

      def initialize(options = {})
        requires!(options, :merchant)
        super
      end

      def authorize(money, creditcard, options = {})
        post = {}
        add_invoice(post, options)
        add_creditcard(post, creditcard)
        add_address(post, creditcard, options)
        add_customer_data(post, options)
        add_pair(post, :payType, PURCHASE_HOLD)
        add_pair(post, :amount, money)

        commit('authonly', post)
      end

      def purchase(money, creditcard, options = {})
        post = {}
        add_invoice(post, options)
        add_creditcard(post, creditcard)
        add_address(post, creditcard, options)
        add_customer_data(post, options)
        add_pair(post, :payType, PURCHASE_NORMAL)
        add_pair(post, :amount, money)

        commit('sale', post)
      end

      def capture(money, authorization, options = {})
        requires!(@options, :login, :password)
        post = {}
        add_pair(post, :loginId, @options[:login])
        add_pair(post, :password, @options[:password])
        add_pair(post, :actionType , "Capture")
        add_pair(post, :payRef, authorization)
        add_pair(post, :amount, money)

        commit('capture', post)
      end

      def void(authorization, options = {})
        requires!(@options, :login, :password)
        post = {}
        add_pair(post, :loginId, @options[:login])
        add_pair(post, :password, @options[:password])
        add_pair(post, :actionType , "Void")
        add_pair(post, :payRef, authorization)

        commit('void', post)
      end

      private

      def add_customer_data(post, options)
        add_pair(post, :lang, options[:lang])
      end

      def add_address(post, creditcard, options)
        post = {}
        if options[:address]
          add_pair(post, :billingFirstName, options[:address][:name].split(" ")[0]) if options[:address][:name]
          add_pair(post, :billingLastName, options[:address][:name].split(" ")[1..-1].join(" ")) if options[:address][:name]
          add_pair(post, :billingStreet1, options[:address][:address1])
          add_pair(post, :billingStreet2, options[:address][:address2])
          add_pair(post, :billingCity, options[:address][:city])
          add_pair(post, :billingState, options[:address][:state])
          add_pair(post, :billingPostalCode, options[:address][:zip])
          add_pair(post, :billingCountry, options[:address][:country])
          add_pair(post, :billingEmail, options[:address][:email])
          add_pair(post, :custIPAddress, options[:address][:ip])
        end
      end

      def add_invoice(post, options)
        add_pair(post, :orderRef, options[:order_id])
        add_pair(post, :currCode, options[:currency])
      end

      def add_creditcard(post, creditcard)
        add_pair(post, :pMethod, creditcard.brand.upcase)
        add_pair(post, :epMonth, creditcard.month)
        add_pair(post, :epYear, creditcard.year)
        add_pair(post, :cardNo, creditcard.number)
        add_pair(post, :cardHolder, creditcard.name)
        add_pair(post, :securityCode, creditcard.verification_value)
      end

      #parse data from response
      def parse(body)
        return_params = parse_response body
        if return_params["successcode"] #purchase & authorize
          success = return_params.delete("successcode") == "0"
        elsif return_params["resultCode"] #capture
          success = return_params.delete("resultCode") == "0"
        end
        message = return_params.delete("errMsg").strip
        options[:test] = test?
        options[:authorization] = return_params.delete("PayRef")
        Response.new(success, message, return_params, options)
      end

      #post action to server
      def commit(action, parameters)
        add_pair(parameters, :merchantId, @options[:merchant])

        puts "parameters=#{parameters}"
        data = post_data(action, parameters)
        puts "data=#{data}"
        raw_response = ssl_post(post_url(action), data)
        puts "raw_response=#{raw_response}"
        response = parse(raw_response)
      end

      #get message from response
      def message_from(response)
      end

      def post_data(action, parameters = {})
        parameters.collect { |key, value| "#{key}=#{CGI.escape(value.to_s)}" }.join("&")
      end

    private
      def post_url(action)
        case action
        when 'authonly', 'sale'
          test? ? self.test_url : self.live_url
        when 'capture', 'void'
          test? ? self.test_merchant_url : self.live_merchant_url
        end
      end

      def add_pair(post, key, value)
        post[key] = value
      end

      def parse_response(body)
        body.split("&").inject({}) do |hash, key_value|
          key, value = key_value.split("=")
          hash[key] = value
          hash
        end
      end
    end
  end
end

