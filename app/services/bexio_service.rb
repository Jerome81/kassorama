require 'net/http'
require 'json'
require 'securerandom'
require 'cgi'

class BexioService
  BEXIO_AUTH_URL = "https://auth.bexio.com/realms/bexio/protocol/openid-connect/auth"
  BEXIO_TOKEN_URL = "https://auth.bexio.com/realms/bexio/protocol/openid-connect/token"
  BEXIO_API_URL = "https://api.bexio.com/2.0"
  BEXIO_API_URL_30 = "https://api.bexio.com/3.0"

  attr_reader :client_id, :client_secret, :redirect_uri

  def initialize(redirect_uri = nil)
    # Default redirect UI, can be overridden
    @redirect_uri = redirect_uri || "http://localhost:3000/accounting/bexio_callback"
    @client_id = Setting[:bexio_client_id]
    @client_secret = Setting[:bexio_client_secret]
  end

  def configured?
    @client_id.present? && @client_secret.present?
  end

  def authorize_url
    scope = "openid profile offline_access accounting contact_show"
    state = SecureRandom.hex(16)
    "#{BEXIO_AUTH_URL}?client_id=#{@client_id}&redirect_uri=#{CGI.escape(@redirect_uri)}&scope=#{CGI.escape(scope)}&state=#{state}&response_type=code"
  end

  def exchange_token(code)
    uri = URI(BEXIO_TOKEN_URL)
    res = Net::HTTP.post_form(uri, {
      client_id: @client_id,
      client_secret: @client_secret,
      redirect_uri: @redirect_uri,
      code: code,
      grant_type: 'authorization_code'
    })

    handle_token_response(res)
  end

  def refresh_token!
    refresh_token = Setting[:bexio_refresh_token]
    return nil unless refresh_token

    uri = URI(BEXIO_TOKEN_URL)
    res = Net::HTTP.post_form(uri, {
      client_id: @client_id,
      client_secret: @client_secret,
      refresh_token: refresh_token,
      grant_type: 'refresh_token'
    })

    handle_token_response(res)
  end

  def send_manual_entry(date, description, lines)
    ensure_valid_token!
    # access_token = Setting[:bexio_access_token] # Not needed here as request() handles it
    # Payload structure:
    # {
    #   "date": "2023-10-27",
    #   "lines": [
    #     {
    #       "description": "...",
    #       "amount": 100.0,
    #       "debit_account_id": 100,
    #       "credit_account_id": 200,
    #       "tax_id": 5  (optional)
    #     }
    #   ]
    # }
    #
    # Wait, Bexio usually separates debit and credit or uses booking types.
    # Checking typical structure for manual journal entry:
    # "lines": [
    #   { 
    #     "type": "debit" or "credit"? 
    #     Actually, Bexio usually wants:
    #     "debit_account_id" and "credit_account_id" per line if it simulates a transaction between two.
    #     OR detailed list of splits.
    #
    #     According to simple docs: 
    #     POST /accounting/manual_entries
    #     {
    #         "date": "...",
    #         "lines": [
    #             { "debit_account_id": ..., "credit_account_id": ..., "amount": ..., "description": ... }
    #         ]
    #     }
    # ]
    #
    # Our `Entry` model has debit_account, credit_account (as strings like "1000", "3200").
    # We need to map these Account Numbers to Bexio Account IDs.
    #
    # CRITICAL: This implementation assumes we have a way to map the account numbers (e.g. "1000") to IDs.
    # Since we don't have that mapping yet, we'll try to fetch accounts first or assume the user must provide mapping?
    # For now, let's try to lookup account by number if possible, or fail gracefully.
    #
    # Let's add a helper to fetch account ID by number.
    
    url = "#{BEXIO_API_URL_30}/accounting/manual_entries"

    # Transform lines to Bexio format
    
    
    lines.each do |line|
        debit_id = find_account_id_by_number(line[:debit_account])
        credit_id = find_account_id_by_number(line[:credit_account])
        
        unless debit_id && credit_id
            raise "Could not find Bexio Account ID for #{line[:debit_account]} or #{line[:credit_account]}"
        end
        
        # Look up Tax ID
        tax_id = nil
        tax_account_id = nil
        
        if line[:tax_code].present?
          # Looks up the tax code (e.g. 'UN81') in the imported Bexio tax codes
          if tax_obj = BexioTaxCode.find_by(name: line[:tax_code])
             tax_id = tax_obj.bexio_id.to_i
             # If tax is present, we need a tax_account_id. 
             # Assuming usually the same as credit_account_id or handled by Bexio logic implies booking account.
             tax_account_id = credit_id 
          end
        end
        
        entry_line = {
            description: line[:description],
            amount: line[:amount].to_f,
            debit_account_id: debit_id,
            credit_account_id: credit_id,
            tax_id: tax_id, 
            tax_account_id: tax_account_id, 
            currency_id: 1, # Default to CHF?
            currency_factor: 1
        }
        
        bexio_entries = []
        bexio_entries << entry_line
        payload = {
            type: "manual_single_entry",
            date: date.to_s,
            reference_nr: description,
            entries: bexio_entries
        }

        response = request(:post, url, payload)
        
        if response.code.to_i >= 200 && response.code.to_i < 300
            JSON.parse(response.body)
        else
            raise "Bexio API Error: #{response.body}"
        end
    end


  end

  def fetch_accounts
    # GET /2.0/accounts (General Ledger Accounts)
    url = "#{BEXIO_API_URL}/accounts"
    response = request(:get, url)
    
    if response.code.to_i == 200
        JSON.parse(response.body)
    else
        raise "Failed to fetch Bexio accounts: #{response.code} - #{response.body}"
    end
  end

  def fetch_taxes
    # GET /3.0/taxes
    url = "#{BEXIO_API_URL_30}/taxes"
    response = request(:get, url)
    
    if response.code.to_i == 200
      JSON.parse(response.body)
    else
      raise "Failed to fetch Bexio taxes: #{response.code} - #{response.body}"
    end
  end

  private

  def handle_token_response(res)
    data = JSON.parse(res.body)
    if data['access_token']
      Setting[:bexio_access_token] = data['access_token']
      Setting[:bexio_refresh_token] = data['refresh_token']
      # Setting[:bexio_expires_at] = Time.now + data['expires_in'].to_i # Optional
      true
    else
      false
    end
  end

  def ensure_valid_token!
    # Basic check - if we get 401 later we retry, but here we can check expiration if we stored it.
    # For now, just rely on try/catch logic or explicit refresh if needed.
    # Ideally, we check simplistic validity or just refresh if missing.
    unless Setting[:bexio_access_token]
        raise "No access token. Please authenticate first."
    end
  end

  def request(method, url, payload = nil)
    uri = URI(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    
    req = nil
    if method == :post
        req = Net::HTTP::Post.new(uri.request_uri)
        req.body = payload.to_json if payload
    else
        req = Net::HTTP::Get.new(uri.request_uri)
    end
    
    req['Authorization'] = "Bearer #{Setting[:bexio_access_token]}"
    req['Accept'] = 'application/json'
    req['Content-Type'] = 'application/json'
    
    res = http.request(req)
    
    # Auto-refresh token on 401
    if res.code == '401'
        if refresh_token!
            # Retry once
            req['Authorization'] = "Bearer #{Setting[:bexio_access_token]}"
            res = http.request(req)
        end
    end
    
    res
  end

  # Helper: We likely need to cache this map to avoid N+1 API calls
  def find_account_id_by_number(number)
    # 1. Try DB lookup (BexioAccount)
    if account = BexioAccount.find_by(account_number: number.to_s)
        return account.bexio_id.to_i
    end
    
    # 2. Fallback to API map if not in DB (Optional, but safe)
    # Memoize in instance for the duration of the request
    @accounts_map ||= fetch_accounts_map
    @accounts_map[number.to_s]
  end

  def fetch_accounts_map
    accounts = fetch_accounts
    # Map: "1000" => 15 (id)
    map = {}
    accounts.each do |acc|
        manual_account_number = acc['account_no'] # Field might differ, usually 'account_no' or 'number'
        # In docs: "account_no"
        map[manual_account_number.to_s] = acc['id']
    end
    map
  end
end
