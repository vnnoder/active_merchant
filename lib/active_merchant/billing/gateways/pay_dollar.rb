require 'openssl'
require 'base64'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class PayDollarGateway < Gateway
      class_attribute :test_merchant_url, :live_merchant_url

      PURCHASE_HOLD = 'H'
      PURCHASE_NORMAL = 'N'

      STATUS_ACTIVE = 'A'
      STATUS_INACTIVE = 'I'
      STATUS_DISABLE = 'D'

      LANG_CODE = {
        "Traditional Chinese" => "C",
        "English" => "E",
        "Simplified Chinese" => "X",
        "Korean" => "K",
        "Japanese" => "J",
        "Thai" => "T"
      }

      CURRENCY_CODE = {
        "HKD" => "344",
        "USD" => "840",
        "SGD" => "702",
        "CNY" => "156",
        "JPY" =>  "392",
        "TWD" => "901",
        "AUD" => "036",
        "EUR" => "978",
        "GBP" => "826",
        "CAD" => "124",
        "MOP" => "446",
        "PHP" => "608",
        "THB" => "764",
        "MYR" => "458",
        "IDR" => "360",
        "KRW" => "410",
        "SAR" => "682",
        "NZD" => "554",
        "AED" => "784",
        "BND" => "096"
      }


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

      def authorize(money, payment_source, options = {})
        options.merge! @options
        post = authorize_or_purchase_post(money, payment_source, options, PURCHASE_HOLD)
        add_pair(post, :secureHash, generate_secure_hash(money, PURCHASE_HOLD, options))

        commit('authonly', post)
      end

      def purchase(money, payment_source, options = {})
        options.merge! @options
        post = authorize_or_purchase_post(money, payment_source, options, PURCHASE_NORMAL)
        add_pair(post, :secureHash, generate_secure_hash(money, PURCHASE_NORMAL, options))

        commit('sale', post)
      end

      def capture(money, authorization, options = {})
        options.merge! @options
        requires!(options, :login, :password)
        post = {}
        add_pair(post, :loginId, options[:login])
        add_pair(post, :password, options[:password])
        add_pair(post, :actionType , "Capture")
        add_pair(post, :payRef, authorization)
        add_pair(post, :amount, money)

        commit('capture', post)
      end

      def void(authorization, options = {})
        options.merge! @options
        requires!(options, :login, :password)
        post = {}
        add_pair(post, :loginId, options[:login])
        add_pair(post, :password, options[:password])
        add_pair(post, :actionType , "Void")
        add_pair(post, :payRef, authorization)

        commit('void', post)
      end

      def store(creditcard, options = {})
        options.merge! @options
        requires!(options, :login, :password)
        post = {}

        add_pair(post, :merchantApiId, options[:login])
        add_pair(post, :password, options[:password])
        add_pair(post, :actionType , "Add")
        add_pair(post, :status , STATUS_ACTIVE)
        add_pair(post, :memberId, options[:customer])

        add_pair(post, :account, creditcard.number)
        add_pair(post, :expYear, creditcard.year)
        add_pair(post, :expMonth, creditcard.month)
        add_pair(post, :holderName, creditcard.name)
        add_pair(post, :acctStatus, STATUS_ACTIVE)

        commit('store', post)
      end

      def delete_card(token, options = {})
        options.merge! @options
        requires!(options, :login, :password)
        post = {}

        add_pair(post, :merchantApiId, options[:login])
        add_pair(post, :password, options[:password])
        add_pair(post, :actionType, "Delete")
        add_pair(post, :memberId, options[:customer])

        commit('store', post)
      end

      def retrieve_card(token, options = {})
        options.merge! @options
        requires!(options, :login, :password)
        post = {}

        add_pair(post, :merchantApiId, options[:login])
        add_pair(post, :password, options[:password])
        add_pair(post, :actionType, "Query")
        add_pair(post, :memberId, options[:customer])

        commit('store', post)
      end

      def add_membership(options= {})
        options.merge! @options
        requires!(options, :login, :password)
        post = {}

        add_pair(post, :merchantApiId, options[:login])
        add_pair(post, :password, options[:password])
        add_pair(post, :actionType , "Add")
        add_pair(post, :status , STATUS_ACTIVE)
        add_pair(post, :memberId, options[:customer])
        add_pair(post, :firstName, options[:name].split(" ")[0]) if options[:name]
        add_pair(post, :lastName, options[:name].split(" ")[1..-1].join(" ")) if options[:name]
        #memberGroupId is required, use 1 as default if options[:group] is not provided
        add_pair(post, :memberGroupId, options[:group] || 1)

        commit('membership', post)
      end

      def generate_one_time_token(static_token, amount, options = {})
        options.merge! @options
        requires!(options, :login, :password, :decrypt_key, :decrypt_salt)
        decripted_token = base64_decrypt(static_token, options[:decrypt_key], options[:decrypt_salt])
        post = {}

        add_pair(post, :merchantApiId, options[:login])
        add_pair(post, :password, options[:password])
        add_pair(post, :actionType , "GenerateToken")
        add_pair(post, :memberId, options[:customer])
        add_pair(post, :accountId, 0)
        add_pair(post, :amount, amount)
        add_pair(post, :staticToken, decripted_token)

        add_invoice(post, options)

        commit('store', post)
      end

    private
      def authorize_or_purchase_post(money, payment_source, options = {}, type)
        post = {}
        add_invoice(post, options)
        if payment_source.is_a?(String)
          #purchase with memberpay
          response = generate_one_time_token(payment_source, money, options)
          options[:token] = response.params["token"]
          add_customer_data(post, options)
        else
          add_creditcard(post, payment_source)
        end
        add_address(post, payment_source, options)

        add_pair(post, :lang, options[:lang])
        add_pair(post, :payType, type)
        add_pair(post, :amount, money)
        return post
      end

      def add_customer_data(post, options)
        if options[:customer]
          add_pair(post, :memberPay_memberId, options[:customer])
          add_pair(post, :memberPay_token, options[:token])
          add_pair(post, :memberPay_service, "T")
        end
      end

      def add_address(post, creditcard, options)
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
        if is_xml?(body)
          parse_xml body
        else
          parse_query body
        end
      end

      def parse_xml(body)
        xml = REXML::Document.new(body)
        response_status = params = {}
        xml.elements.each('*/responsestatus/*') do |element|
          response_status[element.name.underscore.to_sym] = element.text
        end
        xml.elements.each('*/response/*') do |element|
          params[element.name.underscore.to_sym] = element.text
        end
        params[:account] = {}
        xml.elements.each('*/response/account/*') do |element|
          params[:account][element.name.underscore.to_sym] = element.text
        end

        success = response_status[:responsecode] == "0"
        message = response_status[:responsemessage]
        options = {}
        options[:test] = test?

        PayDollarResponse.new(success, message, params, options)
      end

      def parse_query(body)
        return_params = parse_response body
        if return_params["successcode"] #purchase & authorize
          success = return_params.delete("successcode") == "0"
        elsif return_params["resultCode"] #capture
          success = return_params.delete("resultCode") == "0"
        end
        message = return_params.delete("errMsg").strip
        options[:test] = test?
        options[:authorization] = return_params.delete("PayRef")
        PayDollarResponse.new(success, message, return_params, options)
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


      def post_data(action, parameters = {})
        parameters.collect { |key, value| "#{key}=#{CGI.escape(value.to_s)}" }.join("&")
      end

      def post_url(action)
        case action
        when 'authonly', 'sale'
          test? ? self.test_url : self.live_url
        when 'capture', 'void'
          test? ? self.test_merchant_url : self.live_merchant_url
        when 'store'
          test? ? "https://test.paydollar.com/b2cDemo/eng/merchant/api/MemberPayApi.jsp" : "https://www.paydollar.com/b2c2/eng/merchant/api/MemberPayApi.jsp"
        when 'membership'
          test? ? "https://test.paydollar.com/b2cDemo/eng/merchant/api/MembershipApi.jsp" : "https://www.paydollar.com/b2c2/eng/merchant/api/MembershipApi.jsp"
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

      def is_xml?(body)
        striped_body = body.strip
        striped_body.start_with?("<") && striped_body.end_with?(">")
      end

      def base64_decrypt(static_token, password, salt)
        aes = OpenSSL::Cipher::AES256.new(:CBC)
        aes.decrypt
        aes.padding = 1
        aes.key = password
        aes.iv = salt
        aes.update(Base64::decode64(static_token))+aes.final
      end

      def generate_secure_hash(money, payment_type, options)
        to_be_hashed = "#{options[:merchant]}|#{options[:order_id]}|#{options[:currency]}|#{money}|#{payment_type}|#{options[:secure_hash_secret]}"
        puts "to_be_hashed: #{to_be_hashed}"
        Digest::SHA1.hexdigest to_be_hashed
      end
    end

    class PayDollarResponse < Response
      # add a method to response so we can easily get the token
      # for Validate transactions
      def token
        @params["statictoken"]
      end
    end
  end
end

