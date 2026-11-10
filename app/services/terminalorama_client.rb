require "net/http"
require "json"
require "uri"

class TerminaloramaClient
  class PaymentError < StandardError
    attr_reader :result_code, :overall_result, :http_status, :response_body

    def initialize(message, result_code: nil, overall_result: nil, http_status: nil, response_body: nil)
      super(message)
      @result_code = result_code
      @overall_result = overall_result
      @http_status = http_status
      @response_body = response_body
    end
  end

  DEFAULT_URL = "http://127.0.0.1:8080".freeze

  def self.base_url
    ENV.fetch("TERMINALORAMA_URL", DEFAULT_URL)
  end

  def self.pay(ip:, port: 4100, amount:, currency: "CHF", reference_number: nil, timeout: 90)
    post("/pay", {
      ip: ip,
      port: port || 4100,
      amount: amount.to_f.round(2),
      currency: currency,
      reference_number: reference_number,
      timeout: timeout
    }.compact, open_timeout: 5, read_timeout: timeout + 10)
  end

  def self.status(ip:, port: 4100)
    post("/status", { ip: ip, port: port || 4100 }, open_timeout: 5, read_timeout: 20)
  end

  def self.abort(ip:, port: 4100)
    post("/abort", { ip: ip, port: port || 4100 }, open_timeout: 5, read_timeout: 15)
  end

  def self.post(path, payload, open_timeout: 5, read_timeout: 95)
    uri = URI.join(base_url, path)
    http = Net::HTTP.new(uri.host, uri.port)
    http.open_timeout = open_timeout
    http.read_timeout = read_timeout

    request = Net::HTTP::Post.new(uri.request_uri, { "Content-Type" => "application/json" })
    request.body = JSON.generate(payload)

    response = if defined?(ActiveSupport::Dependencies) && ActiveSupport::Dependencies.respond_to?(:interlock)
                 ActiveSupport::Dependencies.interlock.permit_concurrent_loads { http.request(request) }
               else
                 http.request(request)
               end
    body = JSON.parse(response.body) rescue {}

    if response.code.to_i == 200 && body["success"]
      body
    else
      msg = body["result_message"].presence || body["error"].presence || "Kartenzahlung fehlgeschlagen (HTTP #{response.code})"
      raise PaymentError.new(
        msg,
        result_code: body["result_code"],
        overall_result: body["overall_result"],
        http_status: response.code.to_i,
        response_body: body
      )
    end
  rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH, SocketError => e
    raise PaymentError.new("Terminalorama-Server (#{base_url}) nicht erreichbar: #{e.message}", result_code: -1, http_status: 502)
  rescue Net::OpenTimeout, Net::ReadTimeout
    raise PaymentError.new("Zeitüberschreitung bei der Kommunikation mit dem Kartenterminal", result_code: -1, http_status: 504)
  end
end

